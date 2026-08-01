from flask import Flask, jsonify

app = Flask(__name__)


@app.route("/", methods=["GET"])
def index():
    return jsonify({"message": "Welcome to the Flask CI/CD demo app"}), 200


@app.route("/health", methods=["GET"])
def health():
    """
    Health/status endpoint used by the deploy-verification gate in the
    CI/CD pipeline. Must return 200 with a simple JSON body when the
    app is up and able to serve requests.
    """
    return jsonify({"status": "ok"}), 200


@app.route("/items/<int:item_id>", methods=["GET"])
def get_item(item_id):
    """
    Simple parameterised route used to exercise both the success and
    failure paths in the pytest suite.
    """
    items = {1: "apple", 2: "banana", 3: "cherry"}
    if item_id not in items:
        return jsonify({"error": "item not found"}), 404
    return jsonify({"id": item_id, "name": items[item_id]}), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
