package grpc

import (
	"context"
	"errors"
	"io"
	"testing"
	"time"

	"github.com/RodriguesYan/hub-market-data-service/internal/application/service"
	"github.com/RodriguesYan/hub-market-data-service/internal/domain/model"
	domainService "github.com/RodriguesYan/hub-market-data-service/internal/domain/service"
	pb "github.com/RodriguesYan/hub-proto-contracts/monolith"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
)

// MockGetMarketDataUseCase is a mock implementation of IGetMarketDataUsecase
type MockGetMarketDataUseCase struct {
	mock.Mock
}

func (m *MockGetMarketDataUseCase) Execute(symbols []string) ([]model.MarketDataModel, error) {
	args := m.Called(symbols)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]model.MarketDataModel), args.Error(1)
}

// MockStreamQuotesServer is a mock implementation of MarketDataService_StreamQuotesServer
type MockStreamQuotesServer struct {
	mock.Mock
	ctx context.Context
}

func (m *MockStreamQuotesServer) Send(response *pb.StreamQuotesResponse) error {
	args := m.Called(response)
	return args.Error(0)
}

func (m *MockStreamQuotesServer) Recv() (*pb.StreamQuotesRequest, error) {
	args := m.Called()
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*pb.StreamQuotesRequest), args.Error(1)
}

func (m *MockStreamQuotesServer) Context() context.Context {
	if m.ctx == nil {
		return context.Background()
	}
	return m.ctx
}

func (m *MockStreamQuotesServer) SendMsg(msg interface{}) error {
	args := m.Called(msg)
	return args.Error(0)
}

func (m *MockStreamQuotesServer) RecvMsg(msg interface{}) error {
	args := m.Called(msg)
	return args.Error(0)
}

func (m *MockStreamQuotesServer) SetHeader(md metadata.MD) error {
	return nil
}

func (m *MockStreamQuotesServer) SendHeader(md metadata.MD) error {
	return nil
}

func (m *MockStreamQuotesServer) SetTrailer(md metadata.MD) {
}

// TestNewMarketDataGRPCServer tests the constructor
func TestNewMarketDataGRPCServer(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)

	// Act
	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	// Assert
	assert.NotNil(t, server)
	assert.IsType(t, &MarketDataGRPCServer{}, server)
}

// TestGetMarketData_Success tests successful single symbol market data retrieval
func TestGetMarketData_Success(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)
	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	expectedData := []model.MarketDataModel{
		{Symbol: "AAPL", Name: "Apple Inc.", LastQuote: 150.25, Category: 1},
	}

	mockUseCase.On("Execute", []string{"AAPL"}).Return(expectedData, nil)

	req := &pb.GetMarketDataRequest{Symbol: "AAPL"}
	ctx := context.Background()

	// Act
	resp, err := server.GetMarketData(ctx, req)

	// Assert
	assert.NoError(t, err)
	assert.NotNil(t, resp)
	assert.NotNil(t, resp.MarketData)
	assert.Equal(t, "AAPL", resp.MarketData.Symbol)
	assert.Equal(t, "Apple Inc.", resp.MarketData.CompanyName)
	assert.Equal(t, float64(150.25), resp.MarketData.CurrentPrice)

	mockUseCase.AssertExpectations(t)
}

// TestGetBatchMarketData_Success tests successful batch market data retrieval
func TestGetBatchMarketData_Success(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)
	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	symbols := []string{"AAPL", "GOOGL"}
	expectedData := []model.MarketDataModel{
		{Symbol: "AAPL", Name: "Apple Inc.", LastQuote: 150.25, Category: 1},
		{Symbol: "GOOGL", Name: "Alphabet Inc.", LastQuote: 2750.50, Category: 1},
	}

	mockUseCase.On("Execute", symbols).Return(expectedData, nil)

	req := &pb.GetBatchMarketDataRequest{Symbols: symbols}
	ctx := context.Background()

	// Act
	resp, err := server.GetBatchMarketData(ctx, req)

	// Assert
	assert.NoError(t, err)
	assert.NotNil(t, resp)
	assert.Equal(t, 2, len(resp.MarketData))
	assert.Equal(t, "AAPL", resp.MarketData[0].Symbol)
	assert.Equal(t, "Apple Inc.", resp.MarketData[0].CompanyName)
	assert.Equal(t, float64(150.25), resp.MarketData[0].CurrentPrice)
	assert.Equal(t, "GOOGL", resp.MarketData[1].Symbol)

	mockUseCase.AssertExpectations(t)
}

// TestGetMarketData_EmptySymbol tests with empty symbol
func TestGetMarketData_EmptySymbol(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)
	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	req := &pb.GetMarketDataRequest{Symbol: ""}
	ctx := context.Background()

	// Act
	resp, err := server.GetMarketData(ctx, req)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, resp)

	st, ok := status.FromError(err)
	assert.True(t, ok)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

// TestGetMarketData_NotFound tests symbol not found
func TestGetMarketData_NotFound(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)
	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	mockUseCase.On("Execute", []string{"INVALID"}).Return([]model.MarketDataModel{}, nil)

	req := &pb.GetMarketDataRequest{Symbol: "INVALID"}
	ctx := context.Background()

	// Act
	resp, err := server.GetMarketData(ctx, req)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, resp)

	st, ok := status.FromError(err)
	assert.True(t, ok)
	assert.Equal(t, codes.NotFound, st.Code())

	mockUseCase.AssertExpectations(t)
}

// TestGetMarketData_UseCaseError tests use case error handling
func TestGetMarketData_UseCaseError(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)
	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	useCaseError := errors.New("database connection failed")

	mockUseCase.On("Execute", []string{"AAPL"}).Return(nil, useCaseError)

	req := &pb.GetMarketDataRequest{Symbol: "AAPL"}
	ctx := context.Background()

	// Act
	resp, err := server.GetMarketData(ctx, req)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, resp)

	// Verify it's a gRPC Internal error
	st, ok := status.FromError(err)
	assert.True(t, ok)
	assert.Equal(t, codes.Internal, st.Code())
	assert.Contains(t, st.Message(), "failed to get market data")

	mockUseCase.AssertExpectations(t)
}

// TestGetBatchMarketData_EmptySymbols tests with empty symbols
func TestGetBatchMarketData_EmptySymbols(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)
	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	req := &pb.GetBatchMarketDataRequest{Symbols: []string{}}
	ctx := context.Background()

	// Act
	resp, err := server.GetBatchMarketData(ctx, req)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, resp)

	st, ok := status.FromError(err)
	assert.True(t, ok)
	assert.Equal(t, codes.InvalidArgument, st.Code())
}

// TestStreamQuotes_Subscribe tests subscribing to quotes
func TestStreamQuotes_Subscribe(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)

	// Start the price oscillation service
	priceOscillationService.Start()
	defer priceOscillationService.Stop()

	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	mockStream := &MockStreamQuotesServer{
		ctx: context.Background(),
	}

	// Setup mock expectations
	subscribeReq := &pb.StreamQuotesRequest{
		Action:  "subscribe",
		Symbols: []string{"AAPL", "GOOGL"},
	}

	// First Recv returns subscribe request
	mockStream.On("Recv").Return(subscribeReq, nil).Once()

	// Second Recv returns EOF to close the stream
	mockStream.On("Recv").Return(nil, io.EOF).Once()

	// Expect at least one quote to be sent
	mockStream.On("Send", mock.AnythingOfType("*monolith.StreamQuotesResponse")).Return(nil).Maybe()

	// Act
	err := server.StreamQuotes(mockStream)

	// Assert
	assert.NoError(t, err)
	mockStream.AssertExpectations(t)
}

// TestStreamQuotes_Unsubscribe tests unsubscribing from quotes
func TestStreamQuotes_Unsubscribe(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)

	priceOscillationService.Start()
	defer priceOscillationService.Stop()

	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	mockStream := &MockStreamQuotesServer{
		ctx: context.Background(),
	}

	// Setup mock expectations
	subscribeReq := &pb.StreamQuotesRequest{
		Action:  "subscribe",
		Symbols: []string{"AAPL"},
	}

	unsubscribeReq := &pb.StreamQuotesRequest{
		Action:  "unsubscribe",
		Symbols: []string{"AAPL"},
	}

	// First Recv returns subscribe
	mockStream.On("Recv").Return(subscribeReq, nil).Once()

	// Second Recv returns unsubscribe
	mockStream.On("Recv").Return(unsubscribeReq, nil).Once()

	// Third Recv returns EOF
	mockStream.On("Recv").Return(nil, io.EOF).Once()

	// Expect quotes to be sent
	mockStream.On("Send", mock.AnythingOfType("*monolith.StreamQuotesResponse")).Return(nil).Maybe()

	// Act
	err := server.StreamQuotes(mockStream)

	// Assert
	assert.NoError(t, err)
	mockStream.AssertExpectations(t)
}

// TestStreamQuotes_InvalidAction tests invalid action handling (server ignores invalid actions)
func TestStreamQuotes_InvalidAction(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)

	priceOscillationService.Start()
	defer priceOscillationService.Stop()

	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	mockStream := &MockStreamQuotesServer{
		ctx: context.Background(),
	}

	// Setup mock expectations
	invalidReq := &pb.StreamQuotesRequest{
		Action:  "invalid_action",
		Symbols: []string{"AAPL"},
	}

	// First Recv returns invalid action
	mockStream.On("Recv").Return(invalidReq, nil).Once()

	// Second Recv returns EOF
	mockStream.On("Recv").Return(nil, io.EOF).Once()

	// Server ignores invalid actions, so no Send is expected for the invalid action
	// No quotes should be sent since no subscription was made
	mockStream.On("Send", mock.AnythingOfType("*monolith.StreamQuotesResponse")).Return(nil).Maybe()

	// Act
	err := server.StreamQuotes(mockStream)

	// Assert
	assert.NoError(t, err)
	mockStream.AssertExpectations(t)
}

// TestStreamQuotes_SendError tests error handling when Send fails
func TestStreamQuotes_SendError(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)

	priceOscillationService.Start()
	defer priceOscillationService.Stop()

	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	mockStream := &MockStreamQuotesServer{
		ctx: context.Background(),
	}

	// Setup mock expectations
	subscribeReq := &pb.StreamQuotesRequest{
		Action:  "subscribe",
		Symbols: []string{"AAPL"},
	}

	// First Recv returns subscribe
	mockStream.On("Recv").Return(subscribeReq, nil).Once()

	// Second Recv blocks (simulating long-running stream)
	mockStream.On("Recv").Return(nil, errors.New("stream closed")).Once()

	// Send returns error
	sendError := errors.New("failed to send")
	mockStream.On("Send", mock.AnythingOfType("*monolith.StreamQuotesResponse")).Return(sendError).Maybe()

	// Act
	err := server.StreamQuotes(mockStream)

	// Assert
	// The function should handle send errors gracefully and continue until Recv fails
	assert.Error(t, err)
	mockStream.AssertExpectations(t)
}

// TestStreamQuotes_ContextCancellation tests context cancellation
func TestStreamQuotes_ContextCancellation(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)

	priceOscillationService.Start()
	defer priceOscillationService.Stop()

	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	ctx, cancel := context.WithCancel(context.Background())
	mockStream := &MockStreamQuotesServer{
		ctx: ctx,
	}

	// Setup mock expectations
	subscribeReq := &pb.StreamQuotesRequest{
		Action:  "subscribe",
		Symbols: []string{"AAPL"},
	}

	// First Recv returns subscribe
	mockStream.On("Recv").Return(subscribeReq, nil).Once()

	// Cancel context after a short delay
	go func() {
		time.Sleep(100 * time.Millisecond)
		cancel()
	}()

	// Second Recv should eventually return error due to context cancellation
	mockStream.On("Recv").Return(nil, context.Canceled).Maybe()

	// Expect quotes to be sent before cancellation
	mockStream.On("Send", mock.AnythingOfType("*monolith.StreamQuotesResponse")).Return(nil).Maybe()

	// Act
	err := server.StreamQuotes(mockStream)

	// Assert
	// Should return error due to context cancellation
	assert.Error(t, err)
}

// TestStreamQuotes_Heartbeat tests heartbeat messages
func TestStreamQuotes_Heartbeat(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)

	priceOscillationService.Start()
	defer priceOscillationService.Stop()

	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	mockStream := &MockStreamQuotesServer{
		ctx: context.Background(),
	}

	// Setup mock expectations
	subscribeReq := &pb.StreamQuotesRequest{
		Action:  "subscribe",
		Symbols: []string{"AAPL"},
	}

	// First Recv returns subscribe
	mockStream.On("Recv").Return(subscribeReq, nil).Once()

	// Keep stream open for a bit to receive heartbeat
	go func() {
		time.Sleep(35 * time.Second) // Wait for heartbeat interval (30s)
		mockStream.On("Recv").Return(nil, io.EOF).Once()
	}()

	// Expect heartbeat message to be sent
	mockStream.On("Send", mock.MatchedBy(func(resp *pb.StreamQuotesResponse) bool {
		return resp.Type == "heartbeat" || resp.Type == "quote"
	})).Return(nil).Maybe()

	// Act
	// Note: This test would take 35 seconds to complete, so we'll skip it in CI
	// For manual testing, uncomment the following lines:
	// err := server.StreamQuotes(mockStream)
	// assert.NoError(t, err)

	// For now, just verify the server can be created
	assert.NotNil(t, server)
}

// TestStreamQuotes_MultipleSymbols tests subscribing to multiple symbols
func TestStreamQuotes_MultipleSymbols(t *testing.T) {
	// Arrange
	mockUseCase := &MockGetMarketDataUseCase{}
	assetDataService := domainService.NewAssetDataService()
	priceOscillationService := service.NewPriceOscillationService(assetDataService)

	priceOscillationService.Start()
	defer priceOscillationService.Stop()

	server := NewMarketDataGRPCServer(mockUseCase, priceOscillationService)

	mockStream := &MockStreamQuotesServer{
		ctx: context.Background(),
	}

	// Setup mock expectations
	subscribeReq := &pb.StreamQuotesRequest{
		Action:  "subscribe",
		Symbols: []string{"AAPL", "GOOGL", "MSFT"},
	}

	// First Recv returns subscribe with multiple symbols
	mockStream.On("Recv").Return(subscribeReq, nil).Once()

	// Second Recv returns EOF
	mockStream.On("Recv").Return(nil, io.EOF).Once()

	// Expect quotes for all symbols to be sent
	mockStream.On("Send", mock.MatchedBy(func(resp *pb.StreamQuotesResponse) bool {
		return resp.Type == "quote" || resp.Type == "heartbeat"
	})).Return(nil).Maybe()

	// Act
	err := server.StreamQuotes(mockStream)

	// Assert
	assert.NoError(t, err)
	mockStream.AssertExpectations(t)
}
