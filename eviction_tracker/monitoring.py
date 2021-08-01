import logging.config
import traceback
import eviction_tracker.config as config

logging.config.dictConfig(config.LOGGING)
logger = logging.getLogger(__name__)


def log_on_exception(func):
    def inner():
        try:
            func()
        except:
            logger.error("uncaught exception: %s", traceback.format_exc())
    return inner
