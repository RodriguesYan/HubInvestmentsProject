package metrics

import (
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
)

// Metrics holds all Prometheus metrics for the Market Data Service
type Metrics struct {
	// gRPC Metrics
	GRPCRequestsTotal       *prometheus.CounterVec
	GRPCRequestDuration     *prometheus.HistogramVec
	GRPCActiveStreams       prometheus.Gauge
	GRPCStreamSubscriptions *prometheus.CounterVec
	GRPCStreamMessages      *prometheus.CounterVec
	GRPCErrors              *prometheus.CounterVec

	// Cache Metrics
	CacheHits              prometheus.Counter
	CacheMisses            prometheus.Counter
	CacheErrors            prometheus.Counter
	CacheOperationDuration *prometheus.HistogramVec

	// Database Metrics
	DBQueriesTotal         *prometheus.CounterVec
	DBQueryDuration        *prometheus.HistogramVec
	DBConnectionPoolActive prometheus.Gauge
	DBConnectionPoolIdle   prometheus.Gauge
	DBErrors               *prometheus.CounterVec

	// Price Oscillation Metrics
	PriceUpdatesTotal        prometheus.Counter
	ActiveSubscribers        prometheus.Gauge
	ActiveSymbols            prometheus.Gauge
	PriceOscillationDuration prometheus.Histogram
	QuotesGenerated          *prometheus.CounterVec

	// System Metrics
	ServiceUptime prometheus.Gauge
	ServiceInfo   *prometheus.GaugeVec
}

// NewMetrics creates and registers all Prometheus metrics
func NewMetrics() *Metrics {
	return &Metrics{
		// gRPC Metrics
		GRPCRequestsTotal: promauto.NewCounterVec(
			prometheus.CounterOpts{
				Name: "market_data_grpc_requests_total",
				Help: "Total number of gRPC requests by method and status",
			},
			[]string{"method", "status"},
		),
		GRPCRequestDuration: promauto.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "market_data_grpc_request_duration_seconds",
				Help:    "Duration of gRPC requests in seconds",
				Buckets: prometheus.DefBuckets,
			},
			[]string{"method"},
		),
		GRPCActiveStreams: promauto.NewGauge(
			prometheus.GaugeOpts{
				Name: "market_data_grpc_active_streams",
				Help: "Number of active gRPC streaming connections",
			},
		),
		GRPCStreamSubscriptions: promauto.NewCounterVec(
			prometheus.CounterOpts{
				Name: "market_data_grpc_stream_subscriptions_total",
				Help: "Total number of stream subscriptions by action",
			},
			[]string{"action"}, // subscribe, unsubscribe
		),
		GRPCStreamMessages: promauto.NewCounterVec(
			prometheus.CounterOpts{
				Name: "market_data_grpc_stream_messages_total",
				Help: "Total number of messages sent through gRPC streams by type",
			},
			[]string{"type"}, // quote, heartbeat, error
		),
		GRPCErrors: promauto.NewCounterVec(
			prometheus.CounterOpts{
				Name: "market_data_grpc_errors_total",
				Help: "Total number of gRPC errors by method and error type",
			},
			[]string{"method", "error_type"},
		),

		// Cache Metrics
		CacheHits: promauto.NewCounter(
			prometheus.CounterOpts{
				Name: "market_data_cache_hits_total",
				Help: "Total number of cache hits",
			},
		),
		CacheMisses: promauto.NewCounter(
			prometheus.CounterOpts{
				Name: "market_data_cache_misses_total",
				Help: "Total number of cache misses",
			},
		),
		CacheErrors: promauto.NewCounter(
			prometheus.CounterOpts{
				Name: "market_data_cache_errors_total",
				Help: "Total number of cache errors",
			},
		),
		CacheOperationDuration: promauto.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "market_data_cache_operation_duration_seconds",
				Help:    "Duration of cache operations in seconds",
				Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1},
			},
			[]string{"operation"}, // get, set, delete
		),

		// Database Metrics
		DBQueriesTotal: promauto.NewCounterVec(
			prometheus.CounterOpts{
				Name: "market_data_db_queries_total",
				Help: "Total number of database queries by operation and status",
			},
			[]string{"operation", "status"},
		),
		DBQueryDuration: promauto.NewHistogramVec(
			prometheus.HistogramOpts{
				Name:    "market_data_db_query_duration_seconds",
				Help:    "Duration of database queries in seconds",
				Buckets: []float64{.001, .005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5},
			},
			[]string{"operation"},
		),
		DBConnectionPoolActive: promauto.NewGauge(
			prometheus.GaugeOpts{
				Name: "market_data_db_connection_pool_active",
				Help: "Number of active database connections",
			},
		),
		DBConnectionPoolIdle: promauto.NewGauge(
			prometheus.GaugeOpts{
				Name: "market_data_db_connection_pool_idle",
				Help: "Number of idle database connections",
			},
		),
		DBErrors: promauto.NewCounterVec(
			prometheus.CounterOpts{
				Name: "market_data_db_errors_total",
				Help: "Total number of database errors by operation and error type",
			},
			[]string{"operation", "error_type"},
		),

		// Price Oscillation Metrics
		PriceUpdatesTotal: promauto.NewCounter(
			prometheus.CounterOpts{
				Name: "market_data_price_updates_total",
				Help: "Total number of price updates generated",
			},
		),
		ActiveSubscribers: promauto.NewGauge(
			prometheus.GaugeOpts{
				Name: "market_data_active_subscribers",
				Help: "Number of active quote subscribers",
			},
		),
		ActiveSymbols: promauto.NewGauge(
			prometheus.GaugeOpts{
				Name: "market_data_active_symbols",
				Help: "Number of symbols with active subscriptions",
			},
		),
		PriceOscillationDuration: promauto.NewHistogram(
			prometheus.HistogramOpts{
				Name:    "market_data_price_oscillation_duration_seconds",
				Help:    "Duration of price oscillation cycle in seconds",
				Buckets: []float64{.01, .05, .1, .25, .5, 1, 2.5, 5},
			},
		),
		QuotesGenerated: promauto.NewCounterVec(
			prometheus.CounterOpts{
				Name: "market_data_quotes_generated_total",
				Help: "Total number of quotes generated by symbol",
			},
			[]string{"symbol"},
		),

		// System Metrics
		ServiceUptime: promauto.NewGauge(
			prometheus.GaugeOpts{
				Name: "market_data_service_uptime_seconds",
				Help: "Service uptime in seconds",
			},
		),
		ServiceInfo: promauto.NewGaugeVec(
			prometheus.GaugeOpts{
				Name: "market_data_service_info",
				Help: "Service information including version and build details",
			},
			[]string{"version", "build_time", "git_commit"},
		),
	}
}

// RecordGRPCRequest records a gRPC request
func (m *Metrics) RecordGRPCRequest(method, status string, duration float64) {
	m.GRPCRequestsTotal.WithLabelValues(method, status).Inc()
	m.GRPCRequestDuration.WithLabelValues(method).Observe(duration)
}

// RecordGRPCError records a gRPC error
func (m *Metrics) RecordGRPCError(method, errorType string) {
	m.GRPCErrors.WithLabelValues(method, errorType).Inc()
}

// RecordStreamSubscription records a stream subscription action
func (m *Metrics) RecordStreamSubscription(action string) {
	m.GRPCStreamSubscriptions.WithLabelValues(action).Inc()
}

// RecordStreamMessage records a stream message sent
func (m *Metrics) RecordStreamMessage(messageType string) {
	m.GRPCStreamMessages.WithLabelValues(messageType).Inc()
}

// IncrementActiveStreams increments the active streams counter
func (m *Metrics) IncrementActiveStreams() {
	m.GRPCActiveStreams.Inc()
}

// DecrementActiveStreams decrements the active streams counter
func (m *Metrics) DecrementActiveStreams() {
	m.GRPCActiveStreams.Dec()
}

// RecordCacheHit records a cache hit
func (m *Metrics) RecordCacheHit() {
	m.CacheHits.Inc()
}

// RecordCacheMiss records a cache miss
func (m *Metrics) RecordCacheMiss() {
	m.CacheMisses.Inc()
}

// RecordCacheError records a cache error
func (m *Metrics) RecordCacheError() {
	m.CacheErrors.Inc()
}

// RecordCacheOperation records a cache operation duration
func (m *Metrics) RecordCacheOperation(operation string, duration float64) {
	m.CacheOperationDuration.WithLabelValues(operation).Observe(duration)
}

// RecordDBQuery records a database query
func (m *Metrics) RecordDBQuery(operation, status string, duration float64) {
	m.DBQueriesTotal.WithLabelValues(operation, status).Inc()
	m.DBQueryDuration.WithLabelValues(operation).Observe(duration)
}

// RecordDBError records a database error
func (m *Metrics) RecordDBError(operation, errorType string) {
	m.DBErrors.WithLabelValues(operation, errorType).Inc()
}

// UpdateDBConnectionPool updates database connection pool metrics
func (m *Metrics) UpdateDBConnectionPool(active, idle int) {
	m.DBConnectionPoolActive.Set(float64(active))
	m.DBConnectionPoolIdle.Set(float64(idle))
}

// RecordPriceUpdate records a price update
func (m *Metrics) RecordPriceUpdate() {
	m.PriceUpdatesTotal.Inc()
}

// UpdateActiveSubscribers updates the active subscribers gauge
func (m *Metrics) UpdateActiveSubscribers(count int) {
	m.ActiveSubscribers.Set(float64(count))
}

// UpdateActiveSymbols updates the active symbols gauge
func (m *Metrics) UpdateActiveSymbols(count int) {
	m.ActiveSymbols.Set(float64(count))
}

// RecordPriceOscillation records a price oscillation cycle duration
func (m *Metrics) RecordPriceOscillation(duration float64) {
	m.PriceOscillationDuration.Observe(duration)
}

// RecordQuoteGenerated records a quote generated for a symbol
func (m *Metrics) RecordQuoteGenerated(symbol string) {
	m.QuotesGenerated.WithLabelValues(symbol).Inc()
}

// UpdateServiceUptime updates the service uptime
func (m *Metrics) UpdateServiceUptime(seconds float64) {
	m.ServiceUptime.Set(seconds)
}

// SetServiceInfo sets the service information
func (m *Metrics) SetServiceInfo(version, buildTime, gitCommit string) {
	m.ServiceInfo.WithLabelValues(version, buildTime, gitCommit).Set(1)
}
