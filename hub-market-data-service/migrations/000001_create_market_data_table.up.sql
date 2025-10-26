CREATE TABLE IF NOT EXISTS market_data (
    id SERIAL PRIMARY KEY,
    symbol VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    category INTEGER NOT NULL,
    last_quote DECIMAL(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_market_data_symbol ON market_data(symbol);

-- Insert initial test data
INSERT INTO market_data (symbol, name, category, last_quote) VALUES
('AAPL', 'Apple Inc.', 1, 150.00),
('MSFT', 'Microsoft Corporation', 1, 300.00),
('GOOGL', 'Alphabet Inc.', 1, 140.00),
('AMZN', 'Amazon.com Inc.', 1, 180.00)
ON CONFLICT (symbol) DO NOTHING;

