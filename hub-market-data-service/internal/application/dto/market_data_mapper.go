package dto

import (
	"github.com/RodriguesYan/hub-market-data-service/internal/domain/model"
)

// MarketDataMapper handles conversion between MarketDataDTO and domain.MarketDataModel
type MarketDataMapper struct{}

// NewMarketDataMapper creates a new market data mapper
func NewMarketDataMapper() *MarketDataMapper {
	return &MarketDataMapper{}
}

// ToDomain converts MarketDataDTO to domain.MarketDataModel
func (m *MarketDataMapper) ToDomain(dto MarketDataDTO) model.MarketDataModel {
	return model.MarketDataModel{
		Symbol:    dto.Symbol,
		Category:  dto.Category,
		LastQuote: dto.LastQuote,
		Name:      dto.Name,
	}
}

// ToDTO converts domain.MarketDataModel to MarketDataDTO
func (m *MarketDataMapper) ToDTO(model model.MarketDataModel) MarketDataDTO {
	return MarketDataDTO{
		Symbol:    model.Symbol,
		Category:  model.Category,
		Name:      model.Name,
		LastQuote: model.LastQuote,
	}
}

// ToDomainSlice converts a slice of MarketDataDTO to slice of domain.MarketDataModel
func (m *MarketDataMapper) ToDomainSlice(dtos []MarketDataDTO) []model.MarketDataModel {
	models := make([]model.MarketDataModel, len(dtos))
	for i, dto := range dtos {
		models[i] = m.ToDomain(dto)
	}
	return models
}
