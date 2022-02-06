from datetime import datetime, date, timedelta


def millis_timestamp(dt):
    return round(dt.timestamp() * 1000)


def millis(d):
    return millis_timestamp(datetime.combine(d, datetime.min.time()))


def file_friendly_timestamp(d):
    return datetime.strftime(d, '%Y-%m-%d-%H:%M:%S')
