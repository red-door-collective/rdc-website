import os

LOGGING = {
    'version': 1,
    'disable_existing_loggers': True,
    'formatters': {
        'standard': {
            'format': '%(asctime)s [%(levelname)s] %(name)s: %(message)s'
        },
        'json': {
            'class': 'pythonjsonlogger.jsonlogger.JsonFormatter',
            'format': '%(asctime)s %(name)s %(levelname)s %(message)s'
        },
        'debug_json': {
            'class': 'pythonjsonlogger.jsonlogger.JsonFormatter',
            'format': '%(asctime)s %(name)s %(levelname)s %(message)s %(process)s %(processName)s %(pathname)s %(lineno)s'
        }
    },
    'handlers': {
        'default': {
            'level': 'INFO',
            'formatter': 'standard',
            'class': 'logging.StreamHandler',
            'stream': 'ext://sys.stdout',  # Default is stderr
        },
        'file': {
            'class': 'logging.handlers.RotatingFileHandler',
            'level': 'DEBUG',
            'formatter': 'json',
            'filename': os.environ['LOG_FILE_PATH']
        }
    },
    'loggers': {
        '': {  # root logger
            'handlers': ['default'],
            'level': 'INFO',
            'propagate': False
        },
        'eviction_tracker.commands': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': False
        },
        'eviction_tracker.jobs': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': False
        },
        'eviction_tracker.detainer_warrants.caselink.common': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': False
        },
        'eviction_tracker.detainer_warrants.caselink.warrants': {
            'handlers': ['file'],
            'level': 'INFO',
            'propagate': False
        }
    }
}
