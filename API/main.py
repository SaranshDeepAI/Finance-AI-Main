from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import yfinance as yf
import pandas as pd
import numpy as np
from langchain_groq import ChatGroq
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential # type: ignore
from tensorflow.keras.layers import LSTM, Dense, Dropout # type: ignore
from tensorflow.keras.callbacks import EarlyStopping # type: ignore

app = FastAPI(title="FinanceAI API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

llm = ChatGroq(
    api_key="Replace With Yours",
    model="meta-llama/llama-4-scout-17b-16e-instruct"
)

class StockRequest(BaseModel):
    ticker: str
    period: str = "1mo"

def get_stock_info(ticker):
    stock = yf.Ticker(ticker)
    info = stock.info
    return {
        "Company": info.get("longName", "N/A"),
        "Sector": info.get("sector", "N/A"),
        "Industry": info.get("industry", "N/A"),
        "Market Cap": info.get("marketCap", "N/A"),
        "PE Ratio": info.get("trailingPE", "N/A"),
        "52W High": info.get("fiftyTwoWeekHigh", "N/A"),
        "52W Low": info.get("fiftyTwoWeekLow", "N/A"),
        "Current Price": info.get("currentPrice", "N/A")
    }

def get_stock_news(ticker, num_articles=5):
    stock = yf.Ticker(ticker)
    news = stock.news
    articles = []
    for article in news[:num_articles]:
        articles.append({
            "title": article.get("content", {}).get("title", "N/A"),
            "summary": article.get("content", {}).get("summary", "N/A"),
            "source": article.get("content", {}).get("provider", {}).get("displayName", "N/A"),
        })
    return articles

def get_stock_data(ticker, period="1mo"):
    stock = yf.Ticker(ticker)
    data = stock.history(period=period)
    data = data[["Open", "High", "Low", "Close", "Volume"]]
    data.index = data.index.tz_localize(None)
    return data

def detect_anomalies(ticker, period="3mo"):
    stock = yf.Ticker(ticker)
    data = stock.history(period=period)
    data.index = data.index.tz_localize(None)

    data["Daily_Return"] = data["Close"].pct_change()
    mean_return = data["Daily_Return"].mean()
    std_return = data["Daily_Return"].std()
    data["Z_Score"] = (data["Daily_Return"] - mean_return) / std_return
    data["Is_Anomaly"] = data["Z_Score"].abs() > 2.0

    anomalies = data[data["Is_Anomaly"] == True]

    anomaly_list = []
    for date, row in anomalies.iterrows():
        anomaly_list.append({
            "date": str(date.date()),
            "close": round(row["Close"], 2),
            "return_pct": round(row["Daily_Return"] * 100, 2),
            "z_score": round(row["Z_Score"], 2),
            "type": "Spike" if row["Daily_Return"] > 0 else "Crash"
        })

    prices = []
    for date, row in data.iterrows():
        prices.append({
            "date": str(date.date()),
            "close": round(row["Close"], 2),
            "is_anomaly": bool(row["Is_Anomaly"])
        })

    return {
        "ticker": ticker,
        "total_anomalies": len(anomaly_list),
        "anomalies": anomaly_list,
        "prices": prices
    }

def forecast_stock(ticker):
    stock = yf.Ticker(ticker)
    data = stock.history(period="1y")
    data.index = data.index.tz_localize(None)
    closes = data["Close"].values.reshape(-1, 1)

    scaler = MinMaxScaler(feature_range=(0, 1))
    scaled = scaler.fit_transform(closes)

    sequence_length = 60
    X, y = [], []
    for i in range(sequence_length, len(scaled)):
        X.append(scaled[i-sequence_length:i, 0])
        y.append(scaled[i, 0])

    X, y = np.array(X), np.array(y)
    X = X.reshape(X.shape[0], X.shape[1], 1)

    split = int(len(X) * 0.8)
    X_train, X_test = X[:split], X[split:]
    y_train, y_test = y[:split], y[split:]

    model = Sequential([
        LSTM(50, return_sequences=True, input_shape=(sequence_length, 1)),
        Dropout(0.2),
        LSTM(50, return_sequences=False),
        Dropout(0.2),
        Dense(25),
        Dense(1)
    ])
    model.compile(optimizer="adam", loss="mean_squared_error")

    early_stop = EarlyStopping(
        monitor="val_loss",
        patience=5,
        restore_best_weights=True
    )

    model.fit(
        X_train, y_train,
        epochs=30,
        batch_size=32,
        validation_split=0.1,
        callbacks=[early_stop],
        verbose=0
    )

    predictions = model.predict(X_test)
    predictions = scaler.inverse_transform(predictions)
    actual = scaler.inverse_transform(y_test.reshape(-1, 1))

    # Next 7 days forecast
    last_sequence = scaled[-sequence_length:]
    future_predictions = []
    current_sequence = last_sequence.copy()

    for _ in range(7):
        input_seq = current_sequence.reshape(1, sequence_length, 1)
        next_pred = model.predict(input_seq, verbose=0)
        future_predictions.append(next_pred[0, 0])
        current_sequence = np.append(current_sequence[1:], next_pred)
        current_sequence = current_sequence.reshape(-1, 1)

    future_prices = scaler.inverse_transform(
        np.array(future_predictions).reshape(-1, 1)
    ).flatten().tolist()

    test_dates = data.index[-len(actual):]
    history_data = []
    for i, (date, act, pred) in enumerate(
        zip(test_dates, actual.flatten(), predictions.flatten())
    ):
        history_data.append({
            "date": str(date.date()),
            "actual": round(float(act), 2),
            "predicted": round(float(pred), 2)
        })

    return {
        "ticker": ticker,
        "forecast_7_days": [round(p, 2) for p in future_prices],
        "history": history_data
    }

@app.get("/")
def home():
    return {"message": "Welcome to FinanceAI API!", "status": "running"}

@app.post("/stock/info")
def stock_info(request: StockRequest):
    info = get_stock_info(request.ticker)
    return {"ticker": request.ticker, "data": info}

@app.post("/stock/news")
def stock_news(request: StockRequest):
    news = get_stock_news(request.ticker)
    return {"ticker": request.ticker, "news": news}

@app.post("/stock/analyze")
def stock_analyze(request: StockRequest):
    info = get_stock_info(request.ticker)
    df = get_stock_data(request.ticker, request.period)
    news = get_stock_news(request.ticker)

    price_change = df["Close"].iloc[-1] - df["Close"].iloc[0]
    price_change_pct = (price_change / df["Close"].iloc[0]) * 100
    headlines = "\n".join([f"- {a['title']}" for a in news])

    prompt = f"""
    You are an expert financial analyst. Analyze this stock:
    Company: {info['Company']}
    Sector: {info['Sector']}
    Current Price: {info['Current Price']}
    PE Ratio: {info['PE Ratio']}
    Market Cap: {info['Market Cap']}
    52W High: {info['52W High']}
    52W Low: {info['52W Low']}
    Price Change: {price_change_pct:.2f}%

    Latest News:
    {headlines}

    Provide:
    1. Overall Sentiment (Bullish/Bearish/Neutral)
    2. Key Strengths
    3. Key Risks
    4. Short term outlook
    5. Final Recommendation with target price
    """

    response = llm.invoke(prompt)
    return {
        "ticker": request.ticker,
        "analysis": response.content
    }

@app.post("/stock/anomaly")
def stock_anomaly(request: StockRequest):
    result = detect_anomalies(request.ticker, request.period)
    return result

@app.post("/stock/forecast")
def stock_forecast(request: StockRequest):
    result = forecast_stock(request.ticker)
    return result

#uvicorn main:app --reload