from flask import Flask, request, jsonify
from google.cloud import firestore
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleRequest
import requests
import json

# Path to your Firebase service account key
SERVICE_ACCOUNT_PATH = "service_account.json"
PROJECT_ID = "garud-21e17"

# Setup credentials
credentials = service_account.Credentials.from_service_account_file(
    SERVICE_ACCOUNT_PATH,
    scopes=[
        "https://www.googleapis.com/auth/datastore",
        "https://www.googleapis.com/auth/firebase.messaging"
    ]
)

# Setup Firestore client
db = firestore.Client(credentials=credentials, project=PROJECT_ID)

app = Flask(__name__)

# Get access token to call FCM
def get_access_token():
    auth_req = GoogleRequest()
    credentials.refresh(auth_req)
    return credentials.token

# Send FCM push notification
def send_fcm_notification(fcm_token, title, body, data=None):
    url = f"https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send"
    headers = {
        "Authorization": f"Bearer {get_access_token()}",
        "Content-Type": "application/json; UTF-8",
    }

    message_payload = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": title,
                "body": body
            },
            "data": data or {}
        }
    }

    response = requests.post(url, headers=headers, data=json.dumps(message_payload))
    return response.status_code, response.text

# http://127.0.0.1:5000/send-notification
# Sample json for body
# {
#   "uid": "Rx41ynvnxAet087FfphfXA8MQzq2",  
#   "title": "Face Detected",
#   "body": "John Doe was detected near your device.",
#   "data": {
#     "name": "John Doe",
#     "client_id": "client-98765"
#   }
# }

@app.route("/send-notification", methods=["POST"])
def notify_user():
    req_data = request.json
    uid = req_data.get("uid")
    title = req_data.get("title")
    body = req_data.get("body")
    data = req_data.get("data")

    if not all([uid, title, body]):
        return jsonify({"error": "Missing uid, title, or body"}), 400

    # Get FCM token from Firestore
    user_doc = db.collection("users").document(uid).get()
    if not user_doc.exists:
        return jsonify({"error": "User not found"}), 404

    fcm_token = user_doc.to_dict().get("token")
    if not fcm_token:
        return jsonify({"error": "FCM token not found"}), 404

    status, response_text = send_fcm_notification(fcm_token, title, body, data)
    return jsonify({"status": status, "response": response_text})

if __name__ == "__main__":
    app.run(debug=True)
