package cache

import (
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/RodriguesYan/hub-market-data-service/internal/domain/model"
	"github.com/RodriguesYan/hub-market-data-service/internal/domain/repository"
	"github.com/RodriguesYan/hub-market-data-service/pkg/cache"
)

// MarketDataCacheRepository implements cache-aside pattern for market data
type MarketDataCacheRepository struct {
	dbRepo      repository.IMarketDataRepository
	cacheClient cache.CacheHandler
	ttl         time.Duration
}

// NewMarketDataCacheRepository creates a new cache repository that wraps the database repository
func NewMarketDataCacheRepository(
	dbRepo repository.IMarketDataRepository,
	cacheClient cache.CacheHandler,
	ttl time.Duration,
) repository.IMarketDataRepository {
	if ttl == 0 {
		ttl = 5 * time.Minute
	}

	return &MarketDataCacheRepository{
		dbRepo:      dbRepo,
		cacheClient: cacheClient,
		ttl:         ttl,
	}
}

func (c *MarketDataCacheRepository) GetMarketData(symbols []string) ([]model.MarketDataModel, error) {
	cachedData, missingSymbols := c.tryGetFromCache(symbols)

	if len(missingSymbols) == 0 {
		log.Printf("Cache HIT: All symbols found in cache: %v", symbols)
		return cachedData, nil
	}

	log.Printf("Cache MISS: Fetching missing symbols from DB: %v", missingSymbols)
	dbData, err := c.dbRepo.GetMarketData(missingSymbols)
	if err != nil {
		if len(cachedData) > 0 {
			log.Printf("DB error, returning partial cached data: %v", err)
			return cachedData, nil
		}
		return nil, fmt.Errorf("failed to fetch from database: %w", err)
	}

	go c.cacheNewData(dbData)

	allData := append(cachedData, dbData...)

	log.Printf("Cache-aside complete: returned %d items (cached: %d, db: %d)",
		len(allData), len(cachedData), len(dbData))

	return allData, nil
}

func (c *MarketDataCacheRepository) tryGetFromCache(symbols []string) ([]model.MarketDataModel, []string) {
	var cachedData []model.MarketDataModel
	var missingSymbols []string

	for _, symbol := range symbols {
		cacheKey := c.buildCacheKey(symbol)

		cachedValue, err := c.cacheClient.Get(cacheKey)
		if err != nil {
			missingSymbols = append(missingSymbols, symbol)
			continue
		}

		var marketData model.MarketDataModel
		if err := json.Unmarshal([]byte(cachedValue), &marketData); err != nil {
			log.Printf("Failed to unmarshal cached data for %s: %v", symbol, err)
			missingSymbols = append(missingSymbols, symbol)
			continue
		}

		cachedData = append(cachedData, marketData)
	}

	return cachedData, missingSymbols
}

func (c *MarketDataCacheRepository) cacheNewData(data []model.MarketDataModel) {
	for _, item := range data {
		cacheKey := c.buildCacheKey(item.Symbol)

		dataBytes, err := json.Marshal(item)
		if err != nil {
			log.Printf("Failed to marshal data for caching %s: %v", item.Symbol, err)
			continue
		}

		if err := c.cacheClient.Set(cacheKey, string(dataBytes), c.ttl); err != nil {
			log.Printf("Failed to cache data for %s: %v", item.Symbol, err)
		} else {
			log.Printf("Successfully cached data for %s", item.Symbol)
		}
	}
}

func (c *MarketDataCacheRepository) buildCacheKey(symbol string) string {
	return fmt.Sprintf("market_data:%s", strings.ToUpper(symbol))
}

func (c *MarketDataCacheRepository) InvalidateCache(symbols []string) error {
	for _, symbol := range symbols {
		cacheKey := c.buildCacheKey(symbol)
		if err := c.cacheClient.Delete(cacheKey); err != nil {
			log.Printf("Failed to invalidate cache for %s: %v", symbol, err)
		} else {
			log.Printf("Successfully invalidated cache for %s", symbol)
		}
	}
	return nil
}

func (c *MarketDataCacheRepository) WarmCache(symbols []string) error {
	log.Printf("Warming cache for symbols: %v", symbols)

	data, err := c.dbRepo.GetMarketData(symbols)
	if err != nil {
		return fmt.Errorf("failed to warm cache: %w", err)
	}

	c.cacheNewData(data)
	return nil
}
