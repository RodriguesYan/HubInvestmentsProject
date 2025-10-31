package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log"
	"sync"
	"sync/atomic"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"

	pb "github.com/RodriguesYan/hub-proto-contracts/monolith"
)

var (
	serverAddrFlag     = flag.String("server", "localhost:50054", "gRPC server address")
	numClientsFlag     = flag.Int("clients", 100, "Number of concurrent clients")
	durationFlag       = flag.Duration("duration", 30*time.Second, "Test duration")
	symbolsPerConnFlag = flag.Int("symbols", 5, "Symbols per connection")
)

type Stats struct {
	successfulConnections int64
	failedConnections     int64
	totalQuotes           int64
	totalHeartbeats       int64
	totalErrors           int64
}

func main() {
	flag.Parse()

	log.SetFlags(log.Ltime)

	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("         Market Data Service - Load Test")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("Server:           %s\n", *serverAddrFlag)
	fmt.Printf("Concurrent Clients: %d\n", *numClientsFlag)
	fmt.Printf("Duration:         %s\n", *durationFlag)
	fmt.Printf("Symbols/Client:   %d\n", *symbolsPerConnFlag)
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

	allSymbols := []string{
		"AAPL", "GOOGL", "MSFT", "AMZN", "TSLA",
		"META", "NVDA", "JPM", "V", "WMT",
		"JNJ", "PG", "MA", "HD", "DIS",
		"BAC", "NFLX", "ADBE", "CRM", "PYPL",
	}

	stats := &Stats{}
	var wg sync.WaitGroup

	startTime := time.Now()

	log.Printf("🚀 Starting %d concurrent clients...", *numClientsFlag)

	for i := 0; i < *numClientsFlag; i++ {
		wg.Add(1)
		go func(clientID int) {
			defer wg.Done()
			runClient(clientID, allSymbols, stats)
		}(i)

		if (i+1)%10 == 0 {
			log.Printf("   Started %d/%d clients", i+1, *numClientsFlag)
		}

		time.Sleep(10 * time.Millisecond)
	}

	log.Println("✅ All clients started")
	log.Println()

	progressTicker := time.NewTicker(5 * time.Second)
	defer progressTicker.Stop()

	go func() {
		for range progressTicker.C {
			printProgress(stats, time.Since(startTime))
		}
	}()

	time.Sleep(*durationFlag)

	log.Println("\n⏰ Test duration completed, waiting for clients to finish...")

	wg.Wait()

	elapsed := time.Since(startTime)

	fmt.Println()
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println("                    Final Results")
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Printf("Test Duration:        %s\n", elapsed.Round(time.Millisecond))
	fmt.Printf("Target Clients:       %d\n", *numClientsFlag)
	fmt.Printf("Successful Conns:     %d (%.1f%%)\n",
		stats.successfulConnections,
		float64(stats.successfulConnections)/float64(*numClientsFlag)*100)
	fmt.Printf("Failed Conns:         %d (%.1f%%)\n",
		stats.failedConnections,
		float64(stats.failedConnections)/float64(*numClientsFlag)*100)
	fmt.Println()
	fmt.Printf("Total Quotes:         %d\n", stats.totalQuotes)
	fmt.Printf("Total Heartbeats:     %d\n", stats.totalHeartbeats)
	fmt.Printf("Total Errors:         %d\n", stats.totalErrors)
	fmt.Println()
	fmt.Printf("Quotes/Second:        %.2f\n", float64(stats.totalQuotes)/elapsed.Seconds())
	fmt.Printf("Quotes/Client:        %.2f\n", float64(stats.totalQuotes)/float64(stats.successfulConnections))
	fmt.Println("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	fmt.Println()

	if stats.failedConnections > int64(*numClientsFlag/10) {
		log.Printf("❌ FAILED: Too many failed connections (%d/%d)",
			stats.failedConnections, *numClientsFlag)
		return
	}

	if stats.totalQuotes == 0 {
		log.Println("❌ FAILED: No quotes received")
		return
	}

	log.Println("✅ Load test completed successfully!")
}

func runClient(clientID int, allSymbols []string, stats *Stats) {
	ctx, cancel := context.WithTimeout(context.Background(), *durationFlag+5*time.Second)
	defer cancel()

	conn, err := grpc.Dial(*serverAddrFlag,
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
		grpc.WithTimeout(5*time.Second),
	)
	if err != nil {
		atomic.AddInt64(&stats.failedConnections, 1)
		return
	}
	defer conn.Close()

	client := pb.NewMarketDataServiceClient(conn)

	stream, err := client.StreamQuotes(ctx)
	if err != nil {
		atomic.AddInt64(&stats.failedConnections, 1)
		return
	}

	symbols := selectSymbols(allSymbols, clientID, *symbolsPerConnFlag)

	err = stream.Send(&pb.StreamQuotesRequest{
		Action:  "subscribe",
		Symbols: symbols,
	})
	if err != nil {
		atomic.AddInt64(&stats.failedConnections, 1)
		return
	}

	atomic.AddInt64(&stats.successfulConnections, 1)

	for {
		resp, err := stream.Recv()
		if err == io.EOF {
			break
		}
		if err != nil {
			if ctx.Err() == context.DeadlineExceeded {
				break
			}
			atomic.AddInt64(&stats.totalErrors, 1)
			break
		}

		switch resp.Type {
		case "quote":
			atomic.AddInt64(&stats.totalQuotes, 1)
		case "heartbeat":
			atomic.AddInt64(&stats.totalHeartbeats, 1)
		case "error":
			atomic.AddInt64(&stats.totalErrors, 1)
		}
	}

	stream.CloseSend()
}

func selectSymbols(allSymbols []string, clientID, count int) []string {
	if count > len(allSymbols) {
		count = len(allSymbols)
	}

	start := (clientID * count) % len(allSymbols)
	selected := make([]string, 0, count)

	for i := 0; i < count; i++ {
		idx := (start + i) % len(allSymbols)
		selected = append(selected, allSymbols[idx])
	}

	return selected
}

func printProgress(stats *Stats, elapsed time.Duration) {
	quotes := atomic.LoadInt64(&stats.totalQuotes)
	heartbeats := atomic.LoadInt64(&stats.totalHeartbeats)
	successful := atomic.LoadInt64(&stats.successfulConnections)
	failed := atomic.LoadInt64(&stats.failedConnections)

	log.Printf("📊 [%s] Conns: %d✓ %d✗ | Quotes: %d (%.1f/s) | Heartbeats: %d",
		elapsed.Round(time.Second),
		successful,
		failed,
		quotes,
		float64(quotes)/elapsed.Seconds(),
		heartbeats,
	)
}
