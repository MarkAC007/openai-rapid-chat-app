# PowerShell script to set up the chat web application on Windows

# Set execution policy to allow script execution (might require admin privileges)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Set up variables
$ProjectDir = Get-Location
$AppFile = "app.py"
$TemplateDir = "templates"
$IndexFile = "index.html"
$ChatFile = "chat.html"
$EnvFile = ".env"

# Create virtual environment
Write-Host "Creating virtual environment..."
python -m venv venv

# Activate virtual environment
Write-Host "Activating virtual environment..."
& .\venv\Scripts\Activate.ps1

# Install required packages
Write-Host "Installing required packages..."
pip install flask openai python-dotenv

# Create app.py with content
Write-Host "Creating $AppFile..."
@"
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
import openai
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
app.secret_key = 'your_secret_key_here'  # Replace with a secure secret key
openai_client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

def get_available_models():
    try:
        models = openai_client.models.list()
        # Filter for chat models (you may want to adjust this filter)
        chat_models = [model.id for model in models.data if model.id.startswith(('gpt-3.5', 'gpt-4'))]
        return chat_models
    except Exception as e:
        print(f"Error fetching models: {e}")
        return ['gpt-3.5-turbo', 'gpt-4']  # Fallback to default models

@app.route('/', methods=['GET', 'POST'])
def index():
    if request.method == 'POST':
        model = request.form['model']
        session['model'] = model
        return redirect(url_for('chat'))
    
    available_models = get_available_models()
    return render_template('index.html', models=available_models)

@app.route('/chat')
def chat():
    if 'model' not in session:
        return redirect(url_for('index'))
    return render_template('chat.html', model=session['model'])

@app.route('/send_message', methods=['POST'])
def send_message():
    user_message = request.form['message']
    model = session.get('model', 'gpt-3.5-turbo')

    response = openai_client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": user_message}
        ]
    )

    assistant_message = response.choices[0].message.content
    return jsonify({'reply': assistant_message})

if __name__ == '__main__':
    app.run(debug=True)
"@ | Out-File -FilePath $AppFile -Encoding UTF8

# Create templates directory
Write-Host "Creating templates directory..."
New-Item -ItemType Directory -Path $TemplateDir -Force | Out-Null

# Create index.html with content
Write-Host "Creating $TemplateDir\$IndexFile..."
@"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>OpenAI Chat</title>
</head>
<body>
    <h1>Start a Chat</h1>
    <form method="post">
        <label for="model">Select OpenAI Model:</label>
        <select name="model" id="model">
            {% for model in models %}
            <option value="{{ model }}">{{ model }}</option>
            {% endfor %}
        </select>
        <input type="submit" value="Start Chat">
    </form>
</body>
</html>
"@ | Out-File -FilePath "$TemplateDir\$IndexFile" -Encoding UTF8

# Create chat.html with content (unchanged from previous version)
Write-Host "Creating $TemplateDir\$ChatFile..."
@"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Chat with {{ model }}</title>
    <style>
        body { font-family: Arial, sans-serif; }
        #chatbox { width: 80%; margin: 0 auto; max-width: 800px; }
        .message { padding: 10px; margin: 5px 0; }
        .user { background-color: #e1ffc7; text-align: right; }
        .assistant { background-color: #f1f1f1; text-align: left; }
        #input-form { width: 80%; margin: 20px auto; max-width: 800px; }
        #message { width: 80%; padding: 10px; }
        #send { padding: 10px 20px; }
    </style>
</head>
<body>
    <h1 style="text-align:center;">Chat with {{ model }}</h1>
    <div id="chatbox"></div>
    <div id="input-form">
        <input type="text" id="message" placeholder="Type your message here" autofocus>
        <button id="send">Send</button>
    </div>
    <script>
        const sendButton = document.getElementById('send');
        const messageInput = document.getElementById('message');
        const chatbox = document.getElementById('chatbox');

        sendButton.addEventListener('click', sendMessage);
        messageInput.addEventListener('keyup', function(event) {
            if (event.key === 'Enter') {
                sendMessage();
            }
        });

        function appendMessage(text, className) {
            const messageDiv = document.createElement('div');
            messageDiv.className = 'message ' + className;
            messageDiv.textContent = text;
            chatbox.appendChild(messageDiv);
            chatbox.scrollTop = chatbox.scrollHeight;
        }

        function sendMessage() {
            const message = messageInput.value.trim();
            if (message === '') return;
            appendMessage('You: ' + message, 'user');
            messageInput.value = '';

            fetch('/send_message', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: 'message=' + encodeURIComponent(message),
            })
            .then(response => response.json())
            .then(data => {
                appendMessage('Assistant: ' + data.reply, 'assistant');
            })
            .catch(error => {
                console.error('Error:', error);
            });
        }
    </script>
</body>
</html>
"@ | Out-File -FilePath "$TemplateDir\$ChatFile" -Encoding UTF8

# Create .env file and prompt for OpenAI API key
Write-Host "Creating $EnvFile..."
$OpenAI_API_Key = Read-Host -Prompt "Enter your OpenAI API Key"
"OPENAI_API_KEY=$OpenAI_API_Key" | Out-File -FilePath $EnvFile -Encoding UTF8

# Deactivate virtual environment
Write-Host "Setup complete!"
Write-Host "To run the app:"
Write-Host "1. Activate the virtual environment: `venv\Scripts\activate`"
Write-Host "2. Run the Flask app: `python app.py`"
Write-Host "3. Open your browser and navigate to http://127.0.0.1:5000/"

