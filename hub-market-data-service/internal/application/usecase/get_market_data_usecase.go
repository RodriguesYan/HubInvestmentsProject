package usecase

import (
	"github.com/RodriguesYan/hub-market-data-service/internal/domain/model"
	"github.com/RodriguesYan/hub-market-data-service/internal/domain/repository"
)

type IGetMarketDataUsecase interface {
	Execute(symbols []string) ([]model.MarketDataModel, error)
}

type GetMarketDataUsecase struct {
	repo repository.IMarketDataRepository
}

func NewGetMarketDataUseCase(repo repository.IMarketDataRepository) IGetMarketDataUsecase {
	return &GetMarketDataUsecase{repo: repo}
}

func (uc *GetMarketDataUsecase) Execute(symbols []string) ([]model.MarketDataModel, error) {
	marketDataList, err := uc.repo.GetMarketData(symbols)

	if err != nil {
		return nil, err
	}

	return marketDataList, nil
}
