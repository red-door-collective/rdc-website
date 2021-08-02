{ listen, pythonpath }:
''
import multiprocessing
from eviction_tracker.extensions import scheduler

workers = multiprocessing.cpu_count() * 2 + 1
bind = "${listen}"

proc_name = "eviction-tracker"
pythonpath = "${pythonpath}"
timeout = 120
statsd_host = "localhost:8125"
user = "eviction-tracker"
group = "within"
preload = True

def on_starting(server):
    print("Starting scheduler")
    flask_app = server.app.wsgi()
    scheduler.init_app(flask_app)
    scheduler.start()

    from eviction_tracker import tasks
''