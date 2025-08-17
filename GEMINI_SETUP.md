# Adding Gemini API Key

To enable the plant details feature that fetches information from Google Gemini AI, you need to:

1. **Get a Gemini API Key:**

   - Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
   - Sign in with your Google account
   - Create a new API key
   - Copy the API key

2. **Add the API Key to your project:**

   **Option A: Environment Variables (Recommended)**

   - Create a `.env` file in your project root
   - Add: `GEMINI_API_KEY=your_api_key_here`
   - Add flutter_dotenv package to pubspec.yaml

   **Option B: Direct replacement (for testing)**

   - Open `lib/screens/virtual_garden_screen.dart`
   - Find line ~248: `const geminiApiKey = "YOUR_API_KEY_HERE";`
   - Replace `YOUR_API_KEY_HERE` with your actual API key

3. **Test the feature:**
   - Run the app
   - Place plants in AR
   - Tap on placed plants to see their details

## Security Note

Never commit API keys to version control. Always use environment variables or secure key management in production.

## Feature Overview

When you tap on a placed plant, the app will:

1. Show a loading indicator
2. Send a request to Google Gemini AI
3. Parse the response into benefits, usage, and description sections
4. Display the information in a beautiful overlay

The overlay includes:

- Medical benefits of the plant
- Usage and application methods
- Botanical description and facts
- Close button to return to AR view
