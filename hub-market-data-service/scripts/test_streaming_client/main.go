package main

import (
	"context"
	"flag"
	"io"
	"log"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "github.com/RodriguesYan/hub-proto-contracts/monolith"
)

var (
	serverAddrFlag = flag.String("server", "localhost:50054", "gRPC server address")
	symbolsFlag    = flag.String("symbols", "AAPL,GOOGL,MSFT", "Comma-separated list of symbols to subscribe")
	durationFlag   = flag.Duration("duration", 30*time.Second, "How long to run the test")
)

func main() {
	flag.Parse()

	log.SetFlags(log.Ltime | log.Lmicroseconds)

	log.Printf("🚀 Starting streaming client test")
	log.Printf("   Server: %s", *serverAddrFlag)
	log.Printf("   Symbols: %s", *symbolsFlag)
	log.Printf("   Duration: %s", *durationFlag)
	log.Println()

	conn, err := grpc.Dial(*serverAddrFlag, grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		log.Fatalf("❌ Failed to connect: %v", err)
	}
	defer conn.Close()

	client := pb.NewMarketDataServiceClient(conn)

	ctx, cancel := context.WithTimeout(context.Background(), *durationFlag+5*time.Second)
	defer cancel()

	stream, err := client.StreamQuotes(ctx)
	if err != nil {
		log.Fatalf("❌ Failed to create stream: %v", err)
	}

	symbolList := strings.Split(*symbolsFlag, ",")
	for i := range symbolList {
		symbolList[i] = strings.TrimSpace(symbolList[i])
	}

	log.Printf("📡 Subscribing to %d symbols...", len(symbolList))
	err = stream.Send(&pb.StreamQuotesRequest{
		Action:  "subscribe",
		Symbols: symbolList,
	})
	if err != nil {
		log.Fatalf("❌ Failed to subscribe: %v", err)
	}
	log.Println("✅ Subscription sent")
	log.Println()

	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	quotesReceived := make(map[string]int)
	heartbeatsReceived := 0
	startTime := time.Now()
	testDuration := time.After(*durationFlag)

	log.Println("📊 Receiving quotes...")
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

	done := make(chan bool)

	go func() {
		for {
			resp, err := stream.Recv()
			if err == io.EOF {
				log.Println("\n🔚 Stream closed by server")
				done <- true
				return
			}
			if err != nil {
				log.Printf("\n❌ Error receiving: %v", err)
				done <- true
				return
			}

			switch resp.Type {
			case "quote":
				if resp.Quote != nil {
					quotesReceived[resp.Quote.Symbol]++
					log.Printf("📈 [%s] %s: $%.2f (%.2f%%) | Vol: %d | Cap: $%.2fB",
						resp.Quote.Symbol,
						resp.Quote.Name,
						resp.Quote.CurrentPrice,
						resp.Quote.ChangePercent,
						resp.Quote.Volume,
						float64(resp.Quote.MarketCap)/1e9,
					)
				}

			case "heartbeat":
				heartbeatsReceived++
				log.Printf("💓 Heartbeat #%d", heartbeatsReceived)

			case "error":
				log.Printf("⚠️  Error: %s", resp.ErrorMessage)

			default:
				log.Printf("❓ Unknown message type: %s", resp.Type)
			}
		}
	}()

	select {
	case <-testDuration:
		log.Println("\n⏰ Test duration completed")
	case <-sigChan:
		log.Println("\n🛑 Interrupted by user")
	case <-done:
		log.Println("\n✅ Stream completed")
	}

	err = stream.CloseSend()
	if err != nil {
		log.Printf("⚠️  Error closing stream: %v", err)
	}

	elapsed := time.Since(startTime)

	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	log.Println("\n📊 Test Summary")
	log.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	log.Printf("Duration: %s", elapsed.Round(time.Millisecond))
	log.Printf("Heartbeats: %d", heartbeatsReceived)
	log.Printf("Total Quotes: %d", sumQuotes(quotesReceived))
	log.Println()
	log.Println("Quotes by Symbol:")
	for symbol, count := range quotesReceived {
		log.Printf("  %s: %d quotes (%.2f quotes/sec)",
			symbol, count, float64(count)/elapsed.Seconds())
	}
	log.Println()

	if len(quotesReceived) == 0 {
		log.Println("❌ FAILED: No quotes received")
		os.Exit(1)
	}

	if len(quotesReceived) < len(symbolList) {
		log.Printf("⚠️  WARNING: Only received quotes for %d/%d symbols",
			len(quotesReceived), len(symbolList))
	}

	log.Println("✅ Test completed successfully!")
}

func sumQuotes(m map[string]int) int {
	total := 0
	for _, count := range m {
		total += count
	}
	return total
}
