// Sample Data Presets - Optimized for clear approve/reject outcomes
const sampleData = {
    1: {
        // Low-Risk Profile: Good income, small loan, stable employment, excellent credit score
        AMT_INCOME_TOTAL: 85000,
        AMT_CREDIT: 12000,
        AMT_ANNUITY: 2400,
        AMT_GOODS_PRICE: 10000,
        DAYS_BIRTH: 38,
        DAYS_EMPLOYED: 12,
        NAME_EDUCATION_LEVEL: "Tertiary_qualification",
        NAME_FAMILY_STATUS: "Married",
        NAME_HOUSING_TYPE: "House_apartment",
        OCCUPATION_TYPE: "Sales_staff",
        REGION_POPULATION_RELATIVE: 0.03,
        CNT_FAM_MEMBERS: 3,
        FLAG_MOBIL: "Yes",
        FLAG_EMAIL: "Yes",
        FLAG_WORK_PHONE: "Yes",
        EXT_SOURCE_3: 0.92
    },
    2: {
        // High-Risk Profile: 17 year old student with no income requesting loan
        AMT_INCOME_TOTAL: 0,
        AMT_CREDIT: 9800,
        AMT_ANNUITY: 1000,
        AMT_GOODS_PRICE: 9000,
        DAYS_BIRTH: 17,
        DAYS_EMPLOYED: 0,
        NAME_EDUCATION_LEVEL: "Secondary_education",
        NAME_FAMILY_STATUS: "Single",
        NAME_HOUSING_TYPE: "With_parents",
        OCCUPATION_TYPE: "Unemployed",
        REGION_POPULATION_RELATIVE: 0.01,
        CNT_FAM_MEMBERS: 1,
        FLAG_MOBIL: "Yes",
        FLAG_EMAIL: "No",
        FLAG_WORK_PHONE: "No",
        EXT_SOURCE_3: 0.1
    }
};

// DOM Elements
const loanForm = document.getElementById('loanForm');
const applicationForm = document.getElementById('applicationForm');
const resultsSection = document.getElementById('resultsSection');
const loadingOverlay = document.getElementById('loadingOverlay');
const clearFormBtn = document.getElementById('clearFormBtn');
const newAssessmentBtn = document.getElementById('newAssessmentBtn');
const generateExplanationBtn = document.getElementById('generateExplanationBtn');
const sampleButtons = document.querySelectorAll('.sample-btn');

// Initialize Event Listeners
document.addEventListener('DOMContentLoaded', () => {
    // Form submission
    loanForm.addEventListener('submit', handleFormSubmit);
    
    // Clear form button
    clearFormBtn.addEventListener('click', clearForm);
    
    // New assessment button
    newAssessmentBtn.addEventListener('click', () => {
        resultsSection.style.display = 'none';
        applicationForm.style.display = 'block';
        applicationForm.scrollIntoView({ behavior: 'smooth' });
    });
    
    // Sample data buttons
    sampleButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            const sampleId = btn.getAttribute('data-sample');
            populateForm(sampleData[sampleId]);
            showToast('Sample data loaded successfully');
        });
    });
    
    // Generate explanation button
    generateExplanationBtn.addEventListener('click', generateExplanation);
    
    // Form field formatting
    setupFormFormatting();
});

// Populate form with data
function populateForm(data) {
    Object.keys(data).forEach(key => {
        const field = document.querySelector(`[name="${key}"]`);
        if (field) {
            field.value = data[key];
        }
    });
}

// Clear form
function clearForm() {
    loanForm.reset();
    showToast('Form cleared');
}

// Handle form submission
async function handleFormSubmit(e) {
    e.preventDefault();
    
    // Show loading overlay
    loadingOverlay.classList.add('active');
    
    try {
        // Get form data
        const formData = new FormData(loanForm);
        const data = Object.fromEntries(formData.entries());
        
        // Store form data for later use
        window.currentFormData = data;
        
        // Call backend API
        const response = await fetch('/api/predict', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(data)
        });
        
        if (!response.ok) {
            throw new Error('Prediction request failed');
        }
        
        const result = await response.json();
        
        if (result.error) {
            throw new Error(result.error);
        }
        
        // Display results
        displayResults(result);
        
        // Scroll to results
        resultsSection.scrollIntoView({ behavior: 'smooth' });
        
    } catch (error) {
        console.error('Error:', error);
        showToast('Error processing application: ' + error.message);
    } finally {
        // Hide loading overlay
        loadingOverlay.classList.remove('active');
    }
}

// Simulate prediction (mock function - replace with actual API call)
function simulatePrediction(data) {
    const income = parseFloat(data.AMT_INCOME_TOTAL);
    const loanAmount = parseFloat(data.AMT_CREDIT);
    const externalScore = parseFloat(data.EXT_SOURCE_3);
    
    // Simple mock logic
    const dti = (loanAmount / income) * 100;
    const baseScore = externalScore * 100;
    
    let approvalProb = baseScore;
    
    if (dti > 80) approvalProb -= 30;
    else if (dti > 50) approvalProb -= 15;
    
    if (data.DAYS_EMPLOYED === "0") approvalProb -= 10;
    
    approvalProb = Math.max(10, Math.min(98, approvalProb));
    const defaultProb = 100 - approvalProb;
    
    const approved = approvalProb > 50;
    
    let creditCategory = "Fair";
    if (approvalProb >= 98) creditCategory = "Excellent";
    else if (approvalProb >= 95) creditCategory = "Good";
    else if (approvalProb >= 92) creditCategory = "Fair";
    else if (approvalProb >= 82) creditCategory = "Poor";
    else creditCategory = "Very Poor";
    
    return {
        decision: approved ? "Approved" : "Rejected",
        approvalProb: approvalProb.toFixed(1),
        defaultProb: defaultProb.toFixed(1),
        creditCategory: creditCategory,
        keyFactors: [
            { name: "Debt-to-Income Ratio", value: dti.toFixed(1) + "%" },
            { name: "External Credit Score", value: (externalScore * 1000).toFixed(0) },
            { name: "Employment Status", value: data.DAYS_EMPLOYED === "0" ? "Unemployed" : "Employed" }
        ]
    };
}

// Display results
function displayResults(result) {
    // Show results section
    resultsSection.style.display = 'block';
    
    // Update timestamp
    const now = new Date();
    document.getElementById('resultTimestamp').textContent = 
        `Generated: ${now.toLocaleString()}`;
    
    // Update decision
    const decisionContainer = document.getElementById('decisionContainer');
    decisionContainer.className = `result-decision ${result.decision.toLowerCase()}`;
    document.getElementById('decisionValue').textContent = result.decision;
    
    // Update metrics
    document.getElementById('approvalProb').textContent = result.approvalProb + '%';
    document.getElementById('defaultProb').textContent = result.defaultProb + '%';
    document.getElementById('creditCategory').textContent = result.creditCategory;
    
    // Update progress bars
    document.getElementById('approvalBar').style.width = result.approvalProb + '%';
    document.getElementById('defaultBar').style.width = result.defaultProb + '%';
    
    // Update credit badge
    const creditBadge = document.getElementById('creditBadge');
    creditBadge.textContent = result.creditCategory;
    creditBadge.style.backgroundColor = getCreditBadgeColor(result.creditCategory);
    
    // Update key factors
    if (result.keyFactors) {
        displayKeyFactors(result.keyFactors);
    }
    
    // Reset explanation
    const explanationContainer = document.getElementById('explanationContainer');
    explanationContainer.innerHTML = `
        <div class="explanation-placeholder">
            Click "Generate Explanation" to receive an AI-powered analysis of this decision using our thinking model.
        </div>
    `;
}

// Display key factors
function displayKeyFactors(factors) {
    const keyFactorsSection = document.getElementById('keyFactorsSection');
    const factorsGrid = document.getElementById('factorsGrid');
    
    factorsGrid.innerHTML = '';
    
    factors.forEach(factor => {
        const factorCard = document.createElement('div');
        factorCard.className = 'factor-card';
        factorCard.innerHTML = `
            <div class="factor-name">${factor.name}</div>
            <div class="factor-value">${factor.value}</div>
        `;
        factorsGrid.appendChild(factorCard);
    });
    
    keyFactorsSection.style.display = 'block';
}

// Get credit badge color
function getCreditBadgeColor(category) {
    const colors = {
        'Excellent': '#00A86B',
        'Good': '#10B981',
        'Fair': '#F59E0B',
        'Poor': '#EF4444',
        'Very Poor': '#DC2626'
    };
    return colors[category] || '#6B7280';
}

// Generate explanation with streaming (like original Flask app)
async function generateExplanation() {
    const explanationContainer = document.getElementById('explanationContainer');
    
    // Show loading state
    explanationContainer.innerHTML = `
        <div class="explanation-loading">
            <div class="spinner-ring" style="width: 24px; height: 24px; border-width: 2px;"></div>
            <span>Generating AI explanation...</span>
        </div>
    `;
    
    // Disable button
    generateExplanationBtn.disabled = true;
    generateExplanationBtn.style.opacity = '0.5';
    
    try {
        // Call streaming endpoint
        const response = await fetch('/api/explain', {
            method: 'GET'
        });
        
        if (!response.ok) {
            throw new Error('Explanation request failed');
        }
        
        // Clear loading and prepare for streaming
        explanationContainer.innerHTML = '<div class="explanation-text" id="streamingText"></div>';
        const streamingText = document.getElementById('streamingText');
        
        // Read the stream
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        
        while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            
            // Append streamed text
            const chunk = decoder.decode(value);
            streamingText.innerHTML += chunk;
            
            // Auto-scroll to bottom
            explanationContainer.scrollTop = explanationContainer.scrollHeight;
        }
        
        showToast('Explanation generated successfully');
        
    } catch (error) {
        console.error('Error:', error);
        explanationContainer.innerHTML = `
            <div class="explanation-text">Error generating explanation: ${error.message}</div>
        `;
    } finally {
        // Re-enable button
        generateExplanationBtn.disabled = false;
        generateExplanationBtn.style.opacity = '1';
    }
}

// Generate mock explanation
function generateMockExplanation() {
    const decision = document.getElementById('decisionValue').textContent;
    const approvalProb = document.getElementById('approvalProb').textContent;
    
    if (decision === "Approved") {
        return `Based on our comprehensive analysis, this loan application has been <strong>approved</strong> with a ${approvalProb} probability of successful repayment. The applicant demonstrates several positive indicators including stable employment history, reasonable debt-to-income ratio, and satisfactory credit scores. The requested loan amount aligns well with the applicant's income level and financial obligations. Key strengths include consistent income verification, manageable existing debt levels, and strong creditworthiness indicators. We recommend proceeding with standard terms and conditions, with regular monitoring during the initial loan period to ensure continued stability.`;
    } else {
        return `After careful evaluation, this loan application has been <strong>rejected</strong> due to elevated risk factors indicating a ${100 - parseFloat(approvalProb)}% probability of default. The primary concerns include unfavorable debt-to-income ratio, which suggests potential difficulty in managing additional financial obligations. Additional risk factors include limited employment stability and credit history indicators that fall below acceptable thresholds. We recommend advising the applicant to focus on improving their financial position through reducing existing debt, establishing more stable employment, and building a stronger credit history before reapplying. Consider offering financial counseling services to help the applicant develop a path toward loan eligibility.`;
    }
}

// Show toast notification
function showToast(message) {
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toastMessage');
    
    toastMessage.textContent = message;
    toast.classList.add('show');
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// Setup form formatting helpers
function setupFormFormatting() {
    // Format currency inputs
    const currencyInputs = [
        'annualIncome',
        'loanAmount',
        'annualRepayment',
        'goodsPrice'
    ];
    
    currencyInputs.forEach(id => {
        const input = document.getElementById(id);
        if (input) {
            input.addEventListener('blur', (e) => {
                const value = parseFloat(e.target.value);
                if (!isNaN(value)) {
                    // Just validate, don't format to keep it as number input
                    if (value < 0) e.target.value = 0;
                }
            });
        }
    });
    
    // Validate age input
    const ageInput = document.getElementById('age');
    if (ageInput) {
        ageInput.addEventListener('blur', (e) => {
            const value = parseFloat(e.target.value);
            if (!isNaN(value)) {
                if (value < 18) {
                    showToast('Age must be at least 18 years');
                    e.target.value = 18;
                } else if (value > 100) {
                    showToast('Please verify the age entered');
                }
            }
        });
    }
}

// Additional UI interactions
document.getElementById('adviseClientBtn')?.addEventListener('click', () => {
    showToast('Client advisory session initiated');
    // Add actual functionality here
});

document.getElementById('saveReportBtn')?.addEventListener('click', () => {
    showToast('Report saved successfully');
    // Add actual save functionality here
});

// Handle saved applications button (placeholder)
document.getElementById('savedApplicationsBtn')?.addEventListener('click', () => {
    showToast('Saved applications feature coming soon');
});

// Mobile menu functionality
const mobileMenuBtn = document.getElementById('mobileMenuBtn');
const mobileMenuOverlay = document.getElementById('mobileMenuOverlay');
const mobileMenuClose = document.getElementById('mobileMenuClose');
const mobileSampleButtons = document.querySelectorAll('.mobile-sample-btn');

mobileMenuBtn?.addEventListener('click', () => {
    mobileMenuOverlay.classList.add('active');
});

mobileMenuClose?.addEventListener('click', () => {
    mobileMenuOverlay.classList.remove('active');
});

mobileMenuOverlay?.addEventListener('click', (e) => {
    if (e.target === mobileMenuOverlay) {
        mobileMenuOverlay.classList.remove('active');
    }
});

mobileSampleButtons.forEach(btn => {
    btn.addEventListener('click', () => {
        const sampleId = btn.getAttribute('data-sample');
        populateForm(sampleData[sampleId]);
        mobileMenuOverlay.classList.remove('active');
        showToast('Sample data loaded successfully');
    });
});
