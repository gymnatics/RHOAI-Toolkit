from flask import Flask, request, jsonify, send_from_directory, Response, session
from flask_cors import CORS
from flask_session import Session
from dotenv import load_dotenv
import numpy as np
import pandas as pd
import requests
import urllib3
import joblib
import os
import sys
import logging

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)
logger = logging.getLogger(__name__)

# Disable SSL warnings for demo
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

app = Flask(__name__, static_folder='../static')
CORS(app)

# Session configuration from environment variables
app.config["SESSION_TYPE"] = "filesystem"
app.config["SESSION_FILE_DIR"] = os.getenv("SESSION_FILE_DIR", "/tmp/flask_session")
app.config["SECRET_KEY"] = os.getenv("SECRET_KEY", "dev-only-change-in-production")
Session(app)

# API Endpoints from environment variables (required)
SKLEARN_API_URL = os.getenv("SKLEARN_API_URL")
LLM_API_URL = os.getenv("LLM_API_URL")

if not SKLEARN_API_URL or not LLM_API_URL:
    raise ValueError("SKLEARN_API_URL and LLM_API_URL environment variables are required")

# Model name for LLM requests (configurable)
LLM_MODEL_NAME = os.getenv("LLM_MODEL_NAME", "qwen3-4b")

# Optional auth tokens (set if token auth is enabled on InferenceService)
SKLEARN_API_TOKEN = os.getenv("SKLEARN_API_TOKEN", "")
LLM_API_TOKEN = os.getenv("LLM_API_TOKEN", "")

def _build_headers(token=""):
    """Build request headers, adding Bearer token if provided."""
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers

# No local model files - using API only
USE_LOCAL_MODEL = False
training_columns = None
model_pipeline = None

print("Using API-only mode (no local models)")
print(f"Sklearn API: {SKLEARN_API_URL}")
print(f"LLM API: {LLM_API_URL}")
print(f"LLM Model: {LLM_MODEL_NAME}")
if SKLEARN_API_TOKEN:
    print("Sklearn auth: Bearer token configured")
if LLM_API_TOKEN:
    print("LLM auth: Bearer token configured")

# Training columns definition (for data preparation)
training_columns = [
    'AMT_INCOME_TOTAL', 'AMT_CREDIT', 'AMT_ANNUITY', 'AMT_GOODS_PRICE',
    'DAYS_BIRTH', 'DAYS_EMPLOYED', 'REGION_POPULATION_RELATIVE', 'CNT_FAM_MEMBERS',
    'FLAG_MOBIL', 'FLAG_EMAIL', 'FLAG_WORK_PHONE',
    'NAME_INCOME_TYPE_Commercial associate', 'NAME_INCOME_TYPE_Maternity leave',
    'NAME_INCOME_TYPE_Pensioner', 'NAME_INCOME_TYPE_State servant',
    'NAME_INCOME_TYPE_Student', 'NAME_INCOME_TYPE_Unemployed', 'NAME_INCOME_TYPE_Working',
    'NAME_EDUCATION_TYPE_Higher education', 'NAME_EDUCATION_TYPE_Incomplete higher',
    'NAME_EDUCATION_TYPE_Lower secondary', 'NAME_EDUCATION_TYPE_Secondary / secondary special',
    'NAME_FAMILY_STATUS_Married', 'NAME_FAMILY_STATUS_Separated',
    'NAME_FAMILY_STATUS_Single / not married', 'NAME_FAMILY_STATUS_Unknown',
    'NAME_FAMILY_STATUS_Widow', 'NAME_HOUSING_TYPE_House / apartment',
    'NAME_HOUSING_TYPE_Municipal apartment', 'NAME_HOUSING_TYPE_Office apartment',
    'NAME_HOUSING_TYPE_Rented apartment', 'NAME_HOUSING_TYPE_With parents',
    'OCCUPATION_TYPE_Cleaning staff', 'OCCUPATION_TYPE_Cooking staff',
    'OCCUPATION_TYPE_Core staff', 'OCCUPATION_TYPE_Drivers', 'OCCUPATION_TYPE_HR staff',
    'OCCUPATION_TYPE_High skill tech staff', 'OCCUPATION_TYPE_IT staff',
    'OCCUPATION_TYPE_Laborers', 'OCCUPATION_TYPE_Low-skill Laborers',
    'OCCUPATION_TYPE_Managers', 'OCCUPATION_TYPE_Medicine staff',
    'OCCUPATION_TYPE_Private service staff', 'OCCUPATION_TYPE_Realty agents',
    'OCCUPATION_TYPE_Sales staff', 'OCCUPATION_TYPE_Secretaries',
    'OCCUPATION_TYPE_Security staff', 'OCCUPATION_TYPE_Waiters/barmen staff'
]

print(f"Using LLM endpoint: {LLM_API_URL}")

def prepare_model_input(data):
    """Prepare input data for sklearn model following EXACT logic from original Flask app"""
    input_data = {}
    
    # Copy ALL raw input fields first
    for key, value in data.items():
        input_data[key] = value
    
    # Encode categorical features (one-hot encoding) - EXACTLY like original
    if "NAME_EDUCATION_LEVEL" in input_data:
        if input_data["NAME_EDUCATION_LEVEL"] == "Tertiary_qualification":
            input_data["NAME_EDUCATION_TYPE_Higher_education"] = 1
            input_data["NAME_EDUCATION_TYPE_Secondary_education"] = 0
        elif input_data["NAME_EDUCATION_LEVEL"] == "Secondary_education":
            input_data["NAME_EDUCATION_TYPE_Higher_education"] = 0
            input_data["NAME_EDUCATION_TYPE_Secondary_education"] = 1
        elif input_data["NAME_EDUCATION_LEVEL"] == "No_secondary_or_higher_education":
            input_data["NAME_EDUCATION_TYPE_Higher_education"] = 0
            input_data["NAME_EDUCATION_TYPE_Secondary_education"] = 0
        del input_data["NAME_EDUCATION_LEVEL"]

    if "NAME_FAMILY_STATUS" in input_data:
        if input_data["NAME_FAMILY_STATUS"] == "Married":
            input_data["NAME_FAMILY_STATUS_Married"] = 1
            input_data["NAME_FAMILY_STATUS_Single"] = 0
        elif input_data["NAME_FAMILY_STATUS"] == "Single":
            input_data["NAME_FAMILY_STATUS_Married"] = 0
            input_data["NAME_FAMILY_STATUS_Single"] = 1
        del input_data["NAME_FAMILY_STATUS"]

    if "NAME_HOUSING_TYPE" in input_data:
        if input_data["NAME_HOUSING_TYPE"] == "House_apartment":
            input_data["NAME_HOUSING_TYPE_House_apartment"] = 1
            input_data["NAME_HOUSING_TYPE_With_parents"] = 0
        elif input_data["NAME_HOUSING_TYPE"] == "With_parents":
            input_data["NAME_HOUSING_TYPE_House_apartment"] = 0
            input_data["NAME_HOUSING_TYPE_With_parents"] = 1
        del input_data["NAME_HOUSING_TYPE"]

    if "OCCUPATION_TYPE" in input_data:
        if input_data["OCCUPATION_TYPE"] == "Laborers":
            input_data["OCCUPATION_TYPE_Laborers"] = 1
            input_data["OCCUPATION_TYPE_Sales_staff"] = 0
        elif input_data["OCCUPATION_TYPE"] == "Sales_staff":
            input_data["OCCUPATION_TYPE_Laborers"] = 0
            input_data["OCCUPATION_TYPE_Sales_staff"] = 1
        elif input_data["OCCUPATION_TYPE"] == "Unemployed":
            input_data["OCCUPATION_TYPE_Laborers"] = 0
            input_data["OCCUPATION_TYPE_Sales_staff"] = 0
        del input_data["OCCUPATION_TYPE"]

    # Process binary fields
    input_data["FLAG_MOBIL"] = 1 if input_data.get("FLAG_MOBIL") == "Yes" else 0
    input_data["FLAG_EMAIL"] = 1 if input_data.get("FLAG_EMAIL") == "Yes" else 0
    input_data["FLAG_WORK_PHONE"] = 1 if input_data.get("FLAG_WORK_PHONE") == "Yes" else 0

    # Convert years to days
    input_data["DAYS_BIRTH"] = int(float(input_data["DAYS_BIRTH"]) * -365.25)
    input_data["DAYS_EMPLOYED"] = int(float(input_data["DAYS_EMPLOYED"]) * -365.25)
    
    # Convert all remaining inputs to floats
    input_data = {key: float(value) for key, value in input_data.items()}

    
    # Now we have encoded data similar to original Flask app
    # Return it - we'll reindex it later with all training columns
    return input_data

def predict_loan_mock(data):
    """Fallback mock prediction when real API fails"""
    try:
        income = float(data.get('AMT_INCOME_TOTAL', 50000))
        loan_amount = float(data.get('AMT_CREDIT', 10000))
        external_score = float(data.get('EXT_SOURCE_3', 0.5))
        employment_years = float(data.get('DAYS_EMPLOYED', 5))
        
        # Calculate debt-to-income ratio
        dti = (loan_amount / income) * 100 if income > 0 else 100
        
        # Base score from external credit score
        approval_prob = external_score * 100
        
        # Adjust based on DTI
        if dti > 80:
            approval_prob -= 30
        elif dti > 50:
            approval_prob -= 15
        elif dti > 30:
            approval_prob -= 5
        
        # Adjust based on employment
        if employment_years == 0:
            approval_prob -= 10
        elif employment_years > 10:
            approval_prob += 5
        
        # Clamp between 10 and 98
        approval_prob = max(10, min(98, approval_prob))
        default_prob = 100 - approval_prob
        
        # Determine credit category
        credit_category = classify_credit_score(approval_prob)
        
        # Decision
        decision = "Approved" if approval_prob > 50 else "Rejected"
        
        # Key factors
        key_factors = [
            {
                "name": "Debt-to-Income Ratio",
                "value": f"{dti:.1f}%",
                "impact": "negative" if dti > 40 else "positive"
            },
            {
                "name": "External Credit Score",
                "value": f"{int(external_score * 1000)}",
                "impact": "positive" if external_score > 0.5 else "negative"
            },
            {
                "name": "Employment Duration",
                "value": f"{employment_years} years",
                "impact": "positive" if employment_years > 0 else "negative"
            }
        ]
        
        return {
            "decision": decision,
            "approvalProb": round(approval_prob, 1),
            "defaultProb": round(default_prob, 1),
            "creditCategory": credit_category,
            "keyFactors": key_factors,
            "timestamp": None
        }
    except Exception as e:
        return {"error": str(e)}

def classify_credit_score(probability_non_default):
    """Classify credit score based on probability"""
    if probability_non_default >= 85:
        return "Excellent"
    elif probability_non_default >= 70:
        return "Good"
    elif probability_non_default >= 55:
        return "Fair"
    elif probability_non_default >= 40:
        return "Poor"
    else:
        return "Very Poor"

def predict_loan(data):
    """Predict using sklearn model - tries API first, falls back to local"""
    
    # ALWAYS try API endpoint first for best demo
    try:
        logger.info("Attempting API prediction...")
        result = predict_loan_api(data)
        if "error" not in result:
            logger.info("✓ Using API endpoint for prediction")
            return result
        else:
            logger.warning(f"API failed: {result['error']}, falling back to local model")
    except Exception as e:
        logger.warning(f"API exception: {e}, falling back to local model")
    
    # Fall back to local model
    if USE_LOCAL_MODEL and model_pipeline is not None:
        logger.info("✓ Using local model for prediction (fallback)")
        return predict_loan_local(data)
    else:
        logger.warning("✓ Using mock prediction (fallback)")
        return predict_loan_mock(data)

def predict_loan_api(data):
    """Call the sklearn API endpoint with predict_proba"""
    try:
        # Prepare input data
        processed_data = prepare_model_input(data)
        
        # Create DataFrame and reindex
        input_data_df = pd.DataFrame([processed_data]).reindex(columns=training_columns, fill_value=0)
        
        # Convert to list for API
        feature_values = input_data_df.values.tolist()[0]
        
        # Prepare payload with outputs field to request predict_proba
        payload = {
            "inputs": [
                {
                    "name": "predict",
                    "shape": [1, len(feature_values)],
                    "datatype": "FP64",
                    "data": [feature_values]
                }
            ],
            "outputs": [
                {"name": "predict_proba"}  # Request probabilities instead of classes
            ]
        }
        
        logger.info(f"Calling sklearn API: {SKLEARN_API_URL}")
        
        response = requests.post(
            SKLEARN_API_URL,
            json=payload,
            headers=_build_headers(SKLEARN_API_TOKEN),
            verify=False,
            timeout=30
        )
        
        if response.status_code != 200:
            logger.error(f"Sklearn API error: {response.status_code} - {response.text[:200]}")
            return {"error": f"API returned {response.status_code}"}
        
        result = response.json()
        logger.info(f"API response: {result}")
        
        # Parse V2 protocol response with predict_proba
        if "outputs" in result and len(result["outputs"]) > 0:
            output = result["outputs"][0]
            if output["name"] == "predict_proba":
                probs = output["data"]
                # Data format: [prob_class_0, prob_class_1]
                probability_non_default = float(probs[0]) * 100
                probability_default = float(probs[1]) * 100
                
                logger.info(f"✓ API prediction: {probability_non_default:.1f}% non-default, {probability_default:.1f}% default")
                
                # Calculate metrics
                return format_prediction_result(data, probability_non_default, probability_default)
        
        return {"error": "Invalid response format"}
            
    except Exception as e:
        logger.error(f"API prediction failed: {str(e)}")
        return {"error": str(e)}

def predict_loan_local(data):
    """Predict using local sklearn model"""
    try:
        # Prepare input data (encodes categoricals, converts to float)
        processed_data = prepare_model_input(data)
        
        # Create DataFrame from processed data (EXACTLY like working Flask app)
        input_data_df = pd.DataFrame([processed_data]).reindex(columns=training_columns, fill_value=0)
        
        # Predict using local model (EXACTLY like working Flask app)
        probabilities = model_pipeline.predict_proba(input_data_df)[0]
        
        if probabilities is not None and len(probabilities) >= 2:
            probability_non_default = float(probabilities[0]) * 100
            probability_default = float(probabilities[1]) * 100
        else:
            raise Exception("Prediction failed")
        
        # Calculate metrics
        return format_prediction_result(data, probability_non_default, probability_default)
        
    except Exception as e:
        logger.error(f"Local prediction error: {str(e)}")
        return {"error": str(e)}

def format_prediction_result(data, probability_non_default, probability_default):
    """Format prediction result (common for both API and local)"""
    try:
        # Determine decision and credit category
        decision = "Rejected" if probability_default > 50 else "Approved"
        credit_category = classify_credit_score(probability_non_default)
        
        # Calculate key factors
        income = float(data.get('AMT_INCOME_TOTAL', 0))
        loan_amount = float(data.get('AMT_CREDIT', 0))
        external_score = float(data.get('EXT_SOURCE_3', 0.5))
        employment_years = float(data.get('DAYS_EMPLOYED', 0))
        credit_score = external_score * 1000
        dti = (loan_amount / income * 100) if income > 0 else 0
        
        # Store in session for streaming /explain route
        session["probabilities"] = [float(probability_non_default), float(probability_default)]
        session["income"] = income
        session["loan_amount"] = loan_amount
        session["credit_score"] = credit_score
        session["dti"] = dti
        session["decision"] = decision
        
        key_factors = [
            {
                "name": "Debt-to-Income Ratio",
                "value": f"{dti:.1f}%",
                "impact": "negative" if dti > 40 else "positive"
            },
            {
                "name": "External Credit Score",
                "value": f"{int(external_score * 1000)}",
                "impact": "positive" if external_score > 0.5 else "negative"
            },
            {
                "name": "Employment Duration",
                "value": f"{employment_years} years",
                "impact": "positive" if employment_years > 0 else "negative"
            }
        ]
        
        return {
            "decision": decision,
            "approvalProb": round(probability_non_default, 1),
            "defaultProb": round(probability_default, 1),
            "creditCategory": credit_category,
            "keyFactors": key_factors,
            "timestamp": None
        }
        
    except Exception as e:
        print(f"Error in predict_loan: {str(e)}")
        return {"error": str(e)}

def call_llm_explanation(data, result):
    """Call real LLM (Qwen) for explanation with anti-repetition parameters"""
    try:
        # Extract key values
        credit_score = int(float(data.get("EXT_SOURCE_3", 0.5)) * 1000)
        income = int(float(data.get("AMT_INCOME_TOTAL", 0)))
        loan_amount = int(float(data.get("AMT_CREDIT", 0)))
        dti = (loan_amount / income * 100) if income > 0 else 0
        decision = "approved" if result['decision'] == "Approved" else "rejected"
        
        # Create prompt for LLM
        system_prompt = "You are a loan officer AI. Summarize the loan decision in 3-4 concise sentences. State the decision, the key reason, and one recommendation. No bullet points or lists."
        user_prompt = f"Loan {decision}. Credit score {credit_score}, income ${income:,}, loan ${loan_amount:,}, DTI {dti:.0f}%."
        
        # Use messages format with anti-repetition parameters (EXACTLY like original Flask app)
        payload = {
            "model": LLM_MODEL_NAME,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
        "max_tokens": 150,
        "temperature": 0.7,
        "top_p": 0.9,
        "frequency_penalty": 0.5,
        "presence_penalty": 0.3,
        "chat_template_kwargs": {"enable_thinking": False}
    }
        
        response = requests.post(
            LLM_API_URL,
            json=payload,
            headers=_build_headers(LLM_API_TOKEN),
            verify=False,
            timeout=30
        )
        
        if response.status_code != 200:
            print(f"LLM API error: {response.status_code} - {response.text}")
            return generate_fallback_explanation(data, result)
        
        llm_result = response.json()
        
        # Parse LLM response - use message.content (not text)
        if "choices" in llm_result and len(llm_result["choices"]) > 0:
            choice = llm_result["choices"][0]
            # Try both formats
            if "message" in choice and "content" in choice["message"]:
                explanation_text = choice["message"]["content"].strip()
            elif "text" in choice:
                explanation_text = choice["text"].strip()
            else:
                explanation_text = ""
            
            if explanation_text:
                return explanation_text
        
        # Fallback if no valid response
        print("No valid LLM response, using fallback")
        return generate_fallback_explanation(data, result)
        
    except Exception as e:
        print(f"Error calling LLM: {str(e)}")
        return generate_fallback_explanation(data, result)

def generate_fallback_explanation(data, result):
    """Generate fallback explanation if LLM fails"""
    decision = result.get('decision', 'Unknown')
    approval_prob = result.get('approvalProb', 0)
    credit_category = result.get('creditCategory', 'Unknown')
    
    income = float(data.get('AMT_INCOME_TOTAL', 0))
    loan_amount = float(data.get('AMT_CREDIT', 0))
    dti = (loan_amount / income * 100) if income > 0 else 0
    
    if decision == "Approved":
        return f"""Based on our comprehensive AI-powered analysis, this loan application has been <strong>approved</strong> with a {approval_prob}% probability of successful repayment.

<strong>Key Strengths:</strong>
The applicant demonstrates several positive indicators that support loan approval:
- Credit score category assessed as <strong>{credit_category}</strong>
- Debt-to-income ratio of {dti:.1f}% is within acceptable parameters
- Financial profile shows capacity to manage the requested loan amount of ${loan_amount:,.0f}

<strong>Risk Assessment:</strong>
The predictive model indicates a low default probability of {result.get('defaultProb', 0):.1f}%. The applicant's income level of ${income:,.0f} provides adequate coverage for the proposed annual repayment obligations.

<strong>Recommendation:</strong>
We recommend proceeding with standard loan terms and conditions. Regular monitoring during the initial 6-month period is advised to ensure continued financial stability."""
    else:
        return f"""After careful AI-driven evaluation, this loan application has been <strong>rejected</strong> due to elevated risk factors indicating a {result.get('defaultProb', 0):.1f}% probability of default.

<strong>Primary Concerns:</strong>
The analysis has identified several risk factors that fall outside our approval parameters:
- Credit score category assessed as <strong>{credit_category}</strong>
- Debt-to-income ratio of {dti:.1f}% exceeds recommended thresholds
- Current financial profile suggests potential difficulty managing additional debt obligations

<strong>Path to Approval:</strong>
We recommend the following steps to improve eligibility for future applications:
1. <strong>Reduce existing debt</strong> - Focus on paying down current obligations to improve debt-to-income ratio
2. <strong>Increase income stability</strong> - Establish consistent employment history or additional income sources
3. <strong>Build credit history</strong> - Maintain timely payments on existing accounts
4. <strong>Consider smaller loan amount</strong> - Reapply with a reduced loan request more aligned with current income"""

@app.route('/')
def index():
    """Serve the main HTML file"""
    return send_from_directory('..', 'index.html')

@app.route('/<path:path>')
def serve_static(path):
    """Serve static files"""
    return send_from_directory('..', path)

@app.route('/api/predict', methods=['POST'])
def predict():
    """Handle prediction requests"""
    try:
        data = request.json
        result = predict_loan(data)
        return jsonify(result)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/explain', methods=['GET'])
def explain_stream():
    """Stream explanation from Qwen word-by-word (like original Flask app)"""
    # Get session data
    probabilities = session.get("probabilities")
    income = session.get("income")
    loan_amount = session.get("loan_amount")
    credit_score = session.get("credit_score")
    dti = session.get("dti")
    decision = session.get("decision")
    
    logger.info(f"Session data: probabilities={probabilities}, decision={decision}")
    sys.stdout.flush()
    
    if not probabilities:
        logger.error("ERROR: No session data found!")
        sys.stdout.flush()
        return Response("No prediction data available. Please run a prediction first.", content_type='text/plain')
    
    # Prepare Qwen request with streaming
    approval_prob = probabilities[0]
    default_prob = probabilities[1]
    system_prompt = "You are a loan officer AI. Summarize the loan decision in 3-4 concise sentences. State the decision, the key reason, and one recommendation. No bullet points or lists."
    user_prompt = f"Loan {decision.lower()}. Credit score {int(credit_score)}, income ${int(income):,}, loan ${int(loan_amount):,}, DTI {dti:.0f}%, approval probability {approval_prob:.0f}%, default risk {default_prob:.0f}%."
    
    payload = {
        "model": LLM_MODEL_NAME,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt}
        ],
        "max_tokens": 150,
        "temperature": 0.7,
        "top_p": 0.9,
        "frequency_penalty": 0.5,
        "presence_penalty": 0.3,
        "stream": True,
        "chat_template_kwargs": {"enable_thinking": False}
    }
    
    def generate():
        """Generator that streams response from LLM"""
        try:
            logger.info(f"Calling LLM with streaming: {LLM_API_URL}")
            sys.stdout.flush()
            
            response = requests.post(
                LLM_API_URL,
                json=payload,
                headers=_build_headers(LLM_API_TOKEN),
                timeout=60,
                verify=False,
                stream=True
            )
            
            logger.info(f"LLM Response status: {response.status_code}")
            if response.status_code != 200:
                error_text = response.text[:500]
                logger.error(f"LLM Error: {error_text}")
                sys.stdout.flush()
            
            if response.status_code == 200:
                # Parse SSE stream
                for line in response.iter_lines():
                    if line:
                        line_str = line.decode('utf-8')
                        if line_str.startswith('data: '):
                            data_str = line_str[6:]  # Remove 'data: ' prefix
                            if data_str == '[DONE]':
                                break
                            try:
                                import json as json_module
                                data = json_module.loads(data_str)
                                if 'choices' in data and len(data['choices']) > 0:
                                    delta = data['choices'][0].get('delta', {})
                                    content = delta.get('content', '')
                                    if content:
                                        yield content
                            except:
                                continue
            else:
                # Fallback to non-streaming
                yield generate_fallback_explanation_text(decision, probabilities[0], income, loan_amount, dti)
        except Exception as e:
            print(f"Streaming error: {e}")
            yield generate_fallback_explanation_text(decision, probabilities[0], income, loan_amount, dti)
    
    return Response(generate(), content_type='text/plain')

def generate_fallback_explanation_text(decision, approval_prob, income, loan_amount, dti):
    """Generate simple fallback text"""
    if decision == "Approved":
        return f"Loan approved with {approval_prob:.1f}% approval probability. DTI ratio of {dti:.1f}% is acceptable. Income of ${income:,.0f} supports loan amount of ${loan_amount:,.0f}."
    else:
        return f"Loan rejected due to high risk ({100-approval_prob:.1f}% default probability). DTI ratio of {dti:.1f}% exceeds thresholds. Income of ${income:,.0f} insufficient for loan amount of ${loan_amount:,.0f}."

@app.route('/api/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "ml_model": "online",
        "llm_model": "online",
        "sklearn_endpoint": SKLEARN_API_URL,
        "llm_endpoint": LLM_API_URL
    })

if __name__ == '__main__':
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", 5000))
    debug = os.getenv("FLASK_DEBUG", "1") == "1"
    app.run(host=host, port=port, debug=debug)
