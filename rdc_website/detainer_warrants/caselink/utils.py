import json
import urllib.parse
from datetime import datetime
from pathlib import Path


def post_json(data):
    res = urllib.parse.parse_qs(data)
    return {k: ",".join(v) for k, v in res.items()}


def save_all_responses(caselink_log):
    for entry in caselink_log:
        save_to_dir(entry["name"], post_json(entry["response"].request.body))


def save_to_dir(name, data, parent_dir=None):
    if not parent_dir:
        time = datetime.now().strftime("%B-%d-%Y-%I:%M")
        parent_dir = "/tmp/caselink-collect-{}".format(time)

    Path(parent_dir).mkdir(parents=True, exist_ok=True)

    with open("{}/{}.json".format(parent_dir, name), "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=4)


def log_response(name, response):
    return {"name": name, "response": response}
