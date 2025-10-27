package model

import (
	"time"
)

type AssetType string

const (
	AssetTypeStock AssetType = "STOCK"
	AssetTypeETF   AssetType = "ETF"
)

type AssetQuote struct {
	Symbol        string
	Name          string
	Type          AssetType
	CurrentPrice  float64
	BasePrice     float64
	Change        float64
	ChangePercent float64
	LastUpdated   time.Time
	Volume        int64
	MarketCap     int64
}

func NewAssetQuote(symbol, name string, assetType AssetType, basePrice float64, volume, marketCap int64) *AssetQuote {
	return &AssetQuote{
		Symbol:        symbol,
		Name:          name,
		Type:          assetType,
		CurrentPrice:  basePrice,
		BasePrice:     basePrice,
		Change:        0.0,
		ChangePercent: 0.0,
		LastUpdated:   time.Now(),
		Volume:        volume,
		MarketCap:     marketCap,
	}
}

func (q *AssetQuote) UpdatePrice(newPrice float64) {
	q.Change = newPrice - q.BasePrice
	q.ChangePercent = (q.Change / q.BasePrice) * 100
	q.CurrentPrice = newPrice
	q.LastUpdated = time.Now()
}

func (q *AssetQuote) IsPositiveChange() bool {
	return q.Change >= 0
}

