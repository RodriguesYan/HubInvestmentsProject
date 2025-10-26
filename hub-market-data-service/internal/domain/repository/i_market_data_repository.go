package repository

import "github.com/RodriguesYan/hub-market-data-service/internal/domain/model"

type IMarketDataRepository interface {
	GetMarketData(symbols []string) ([]model.MarketDataModel, error)
}
