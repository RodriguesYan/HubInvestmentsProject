package grpc

import (
	"context"
	"fmt"
	"log"

	"github.com/RodriguesYan/hub-market-data-service/internal/application/usecase"
	"github.com/RodriguesYan/hub-proto-contracts/common"
	pb "github.com/RodriguesYan/hub-proto-contracts/monolith"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

type MarketDataGRPCServer struct {
	pb.UnimplementedMarketDataServiceServer
	getMarketDataUsecase usecase.IGetMarketDataUsecase
}

func NewMarketDataGRPCServer(getMarketDataUsecase usecase.IGetMarketDataUsecase) *MarketDataGRPCServer {
	return &MarketDataGRPCServer{
		getMarketDataUsecase: getMarketDataUsecase,
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
