class UnhandledRequestException(RuntimeError):
    def __init__(self, task_uuid, xid):
        self.task_uuid = task_uuid
        self.xid = xid
        super().__init__("An unhandled exception occurred during request handling")

    def __structlog__(self):
        return {"xid": self.xid}
