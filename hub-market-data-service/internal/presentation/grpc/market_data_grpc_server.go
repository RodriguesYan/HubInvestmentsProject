package grpc

import (
	"context"
	"fmt"
	"io"
	"log"
	"time"

	"github.com/RodriguesYan/hub-market-data-service/internal/application/service"
	"github.com/RodriguesYan/hub-market-data-service/internal/application/usecase"
	"github.com/RodriguesYan/hub-market-data-service/internal/domain/model"
	"github.com/RodriguesYan/hub-proto-contracts/common"
	pb "github.com/RodriguesYan/hub-proto-contracts/monolith"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type MarketDataGRPCServer struct {
	pb.UnimplementedMarketDataServiceServer
	getMarketDataUsecase    usecase.IGetMarketDataUsecase
	priceOscillationService *service.PriceOscillationService
}

func NewMarketDataGRPCServer(
	getMarketDataUsecase usecase.IGetMarketDataUsecase,
	priceOscillationService *service.PriceOscillationService,
) *MarketDataGRPCServer {
	return &MarketDataGRPCServer{
		getMarketDataUsecase:    getMarketDataUsecase,
		priceOscillationService: priceOscillationService,
	}
}

func (s *MarketDataGRPCServer) GetMarketData(ctx context.Context, req *pb.GetMarketDataRequest) (*pb.GetMarketDataResponse, error) {
	if req.Symbol == "" {
		return nil, status.Error(codes.InvalidArgument, "symbol is required")
	}

	log.Printf("gRPC GetMarketData called for symbol: %s", req.Symbol)

	marketData, err := s.getMarketDataUsecase.Execute([]string{req.Symbol})
	if err != nil {
		log.Printf("Failed to get market data for symbol %s: %v", req.Symbol, err)
		return nil, status.Error(codes.Internal, fmt.Sprintf("failed to get market data: %v", err))
	}

	if len(marketData) == 0 {
		return nil, status.Error(codes.NotFound, fmt.Sprintf("symbol %s not found", req.Symbol))
	}

	data := marketData[0]

	return &pb.GetMarketDataResponse{
		ApiResponse: &common.APIResponse{
			Success: true,
			Message: "Market data retrieved successfully",
		},
		MarketData: &pb.MarketData{
			Symbol:       data.Symbol,
			CompanyName:  data.Name,
			CurrentPrice: float64(data.LastQuote),
		},
	}, nil
}

func (s *MarketDataGRPCServer) GetBatchMarketData(ctx context.Context, req *pb.GetBatchMarketDataRequest) (*pb.GetBatchMarketDataResponse, error) {
	if len(req.Symbols) == 0 {
		return nil, status.Error(codes.InvalidArgument, "at least one symbol is required")
	}

	log.Printf("gRPC GetBatchMarketData called for symbols: %v", req.Symbols)

	marketData, err := s.getMarketDataUsecase.Execute(req.Symbols)
	if err != nil {
		log.Printf("Failed to get batch market data: %v", err)
		return nil, status.Error(codes.Internal, fmt.Sprintf("failed to get market data: %v", err))
	}

	pbMarketData := make([]*pb.MarketData, 0, len(marketData))
	for _, data := range marketData {
		pbMarketData = append(pbMarketData, &pb.MarketData{
			Symbol:       data.Symbol,
			CompanyName:  data.Name,
			CurrentPrice: float64(data.LastQuote),
		})
	}

	return &pb.GetBatchMarketDataResponse{
		ApiResponse: &common.APIResponse{
			Success: true,
			Message: fmt.Sprintf("Retrieved %d market data items", len(marketData)),
		},
		MarketData: pbMarketData,
	}, nil
}

func (s *MarketDataGRPCServer) GetAssetDetails(ctx context.Context, req *pb.GetAssetDetailsRequest) (*pb.GetAssetDetailsResponse, error) {
	return nil, status.Error(codes.Unimplemented, "GetAssetDetails is not yet implemented")
}

func (s *MarketDataGRPCServer) StreamQuotes(stream pb.MarketDataService_StreamQuotesServer) error {
	ctx := stream.Context()

	subscribedSymbols := make(map[string]bool)
	var subscriberID string
	var priceChannel <-chan map[string]*model.AssetQuote

	errChan := make(chan error, 1)
	// Use interface{} to allow sending receive-only channels
	channelUpdateChan := make(chan interface{}, 1)

	go func() {
		for {
			req, err := stream.Recv()
			if err == io.EOF {
				log.Println("Client closed the stream")
				errChan <- nil
				return
			}
			if err != nil {
				log.Printf("Error receiving from stream: %v", err)
				errChan <- err
				return
			}

			switch req.Action {
			case "subscribe":
				for _, symbol := range req.Symbols {
					if !subscribedSymbols[symbol] {
						subscribedSymbols[symbol] = true
					}
				}

				if subscriberID == "" {
					var newChannel <-chan map[string]*model.AssetQuote
					subscriberID, newChannel = s.priceOscillationService.Subscribe(subscribedSymbols)
					log.Printf("New subscription created: %s for symbols: %v", subscriberID, req.Symbols)
					channelUpdateChan <- newChannel
				} else {
					s.priceOscillationService.Unsubscribe(subscriberID)
					var newChannel <-chan map[string]*model.AssetQuote
					subscriberID, newChannel = s.priceOscillationService.Subscribe(subscribedSymbols)
					log.Printf("Updated subscription: %s for symbols: %v", subscriberID, req.Symbols)
					channelUpdateChan <- newChannel
				}

			case "unsubscribe":
				for _, symbol := range req.Symbols {
					delete(subscribedSymbols, symbol)
				}

				if len(subscribedSymbols) == 0 && subscriberID != "" {
					s.priceOscillationService.Unsubscribe(subscriberID)
					subscriberID = ""
					channelUpdateChan <- nil
					log.Println("All symbols unsubscribed, closing subscription")
				} else if subscriberID != "" {
					s.priceOscillationService.Unsubscribe(subscriberID)
					var newChannel <-chan map[string]*model.AssetQuote
					subscriberID, newChannel = s.priceOscillationService.Subscribe(subscribedSymbols)
					log.Printf("Updated subscription after unsubscribe: %s", subscriberID)
					channelUpdateChan <- newChannel
				}
			}
		}
	}()

	heartbeatTicker := time.NewTicker(30 * time.Second)
	defer heartbeatTicker.Stop()

	defer func() {
		if subscriberID != "" {
			s.priceOscillationService.Unsubscribe(subscriberID)
			log.Printf("Cleaned up subscription: %s", subscriberID)
		}
	}()

	for {
		select {
		case <-ctx.Done():
			log.Println("Stream context cancelled")
			return ctx.Err()

		case err := <-errChan:
			if err != nil {
				log.Printf("Stream error: %v", err)
				return err
			}
			return nil

		case update := <-channelUpdateChan:
			if update == nil {
				priceChannel = nil
				log.Println("❌ Price channel set to nil (unsubscribed)")
			} else {
				priceChannel = update.(<-chan map[string]*model.AssetQuote)
				log.Println("✅ Price channel updated and ready to receive quotes")
			}

		case <-heartbeatTicker.C:
			if err := stream.Send(&pb.StreamQuotesResponse{
				Type: "heartbeat",
			}); err != nil {
				log.Printf("Failed to send heartbeat: %v", err)
				return err
			}

		case quotes, ok := <-priceChannel:
			if !ok {
				log.Println("Price channel closed")
				return nil
			}

			log.Printf("📤 Received %d quotes from price channel", len(quotes))

			for _, quote := range quotes {
				pbQuote := &pb.AssetQuote{
					Symbol:        quote.Symbol,
					Name:          quote.Name,
					AssetType:     string(quote.Type),
					CurrentPrice:  quote.CurrentPrice,
					BasePrice:     quote.BasePrice,
					Change:        quote.Change,
					ChangePercent: quote.ChangePercent,
					LastUpdated:   quote.LastUpdated.Format(time.RFC3339),
					Volume:        quote.Volume,
					MarketCap:     quote.MarketCap,
				}

				log.Printf("📤 Sending quote to gRPC stream: %s @ $%.2f", quote.Symbol, quote.CurrentPrice)

				if err := stream.Send(&pb.StreamQuotesResponse{
					Type:  "quote",
					Quote: pbQuote,
				}); err != nil {
					log.Printf("Failed to send quote: %v", err)
					return err
				}

				log.Printf("✅ Quote sent successfully: %s", quote.Symbol)
			}
		}
	}
}
