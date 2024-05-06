import re
import requests

class Navigation:

    BASE = 'https://caselink.nashville.gov'
    FORM_ENCODED = 'application/x-www-form-urlencoded'
    WEBSHELL_PATH = '/cgi-bin/webshell.asp'
    HEADERS = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'en-US,en;q=0.9',
        'Connection': 'keep-alive',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'same-origin',
        'Sec-Fetch-User': '?1',
        'Upgrade-Insecure-Requests': '1',
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'sec-ch-ua': '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
    }
    COOKIES = {
        'tktupdate': '',
    }
    POSTBACK_PATH_REGEX = re.compile(r'(?:self\.location\s*=\s*\")(.+?\.html)\"', re.MULTILINE)

    def __init__(self, path):
        postback_parts = path.removeprefix('/gsapdfs/').split('.')[:-1]
        self.path = path
        self.web_io_handle = postback_parts[0]
        self.parent = postback_parts[1]

    def url(self):
        return Navigation._url(self.path)
    
    @classmethod
    def webshell(cls):
        return cls._url(cls.WEBSHELL_PATH)
    
    @classmethod
    def _url(cls, path):
        return '{}{}'.format(Navigation.BASE, path)
    
    @classmethod
    def headers(cls, more_headers):
        return {**cls.COMMON_HEADERS, **more_headers}
    
    @classmethod
    def login(cls, username, password):
        headers = {
            'Cache-Control': 'max-age=0',
            'Content-Type': cls.FORM_ENCODED,
            'Origin': cls.BASE,
            'Referer': cls._url('///davlvplogin.html?123'),
            'Sec-Fetch-Dest': 'frame'
        }

        data = 'GATEWAY=GATEWAY&CGISCRIPT=webshell.asp&FINDDEFKEY=&XEVENT=VERIFY&WEBIOHANDLE=1714928640773&BROWSER=C*Chrome*124.0*Mac*NOBLOCKTEST&MYPARENT=px&APPID=davlvp&WEBWORDSKEY=SAMPLE&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&OPERCODE={username}&PASSWD={password}'.format(
            username=username,
            password=password
        )

        response = requests.post(cls.webshell(), cookies=cls.COOKIES, headers=headers, data=data)

        return cls(re.search(cls.POSTBACK_PATH_REGEX, response.text)[1])
