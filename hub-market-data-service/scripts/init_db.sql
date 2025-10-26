-- Initialize Market Data Service Database

-- Create market_data table
CREATE TABLE IF NOT EXISTS market_data (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    category INTEGER NOT NULL,
    last_quote DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create index for faster symbol lookups
CREATE INDEX IF NOT EXISTS idx_market_data_symbol ON market_data(symbol);

-- Insert initial test data
INSERT INTO market_data (symbol, name, category, last_quote) VALUES
('AAPL', 'Apple Inc.', 1, 150.00),
('MSFT', 'Microsoft Corporation', 1, 300.00),
('GOOGL', 'Alphabet Inc.', 1, 140.00),
('AMZN', 'Amazon.com Inc.', 1, 180.00)
ON CONFLICT (symbol) DO NOTHING;

-- Grant permissions (if needed)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO market_data_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO market_data_user;

