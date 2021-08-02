{ listen, pythonpath }:
''
import multiprocessing

workers = multiprocessing.cpu_count() * 2 + 1
bind = "${listen}"

proc_name = "eviction-tracker"
pythonpath = "${pythonpath}"
timeout = 120
statsd_host = "localhost:8125"

def on_starting(server):
    print("Starting scheduler")
    flask_app = server.app.wsgi()
    scheduler.init_app(flask_app)
    scheduler.start()

    from eviction_tracker import tasks
''