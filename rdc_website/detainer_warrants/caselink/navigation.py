import re
import requests
import urllib


class Navigation:

    BASE = "https://caselink.nashville.gov"
    FORM_ENCODED = "application/x-www-form-urlencoded"
    WEBSHELL_PATH = "/cgi-bin/webshell.asp"
    HEADERS = {
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
        "Accept-Language": "en-US,en;q=0.9",
        "Connection": "keep-alive",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "same-origin",
        "Sec-Fetch-User": "?1",
        "Upgrade-Insecure-Requests": "1",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "sec-ch-ua": '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"macOS"',
    }
    COOKIES = {
        "tktupdate": "",
    }
    POSTBACK_PATH_REGEX = re.compile(
        r"(?:self\.location\s*=\s*\")(.+?\.html)\"", re.MULTILINE
    )

    def __init__(self, path):
        postback_parts = path.removeprefix("/gsapdfs/").split(".")[:-1]
        self.path = path
        self.web_io_handle = postback_parts[0]
        self.parent = postback_parts[1]

    def url(self):
        return Navigation._url(self.path)

    @classmethod
    def webshell(cls):
        return cls._url(cls.WEBSHELL_PATH)

    @classmethod
    def _extract_postback_url(cls, response):
        return re.search(cls.POSTBACK_PATH_REGEX, response.text)[1]

    @classmethod
    def _url(cls, path):
        return "{}{}".format(Navigation.BASE, path)

    @classmethod
    def merge_headers(cls, more_headers=None):
        if more_headers is None:
            return cls.HEADERS
        return {**cls.HEADERS, **more_headers}

    @classmethod
    def from_response(cls, response):
        return cls(Navigation._extract_postback_url(response))

    @classmethod
    def login(cls, username, password):
        headers = cls.merge_headers(
            {
                "Cache-Control": "max-age=0",
                "Content-Type": cls.FORM_ENCODED,
                "Origin": cls.BASE,
                "Referer": cls._url("///davlvplogin.html?123"),
                "Sec-Fetch-Dest": "frame",
            }
        )

        data = "GATEWAY=GATEWAY&CGISCRIPT=webshell.asp&FINDDEFKEY=&XEVENT=VERIFY&WEBIOHANDLE=1714928640773&BROWSER=C*Chrome*124.0*Mac*NOBLOCKTEST&MYPARENT=px&APPID=davlvp&WEBWORDSKEY=SAMPLE&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&OPERCODE={username}&PASSWD={password}".format(
            username=username, password=password
        )

        response = requests.post(
            cls.webshell(), cookies=cls.COOKIES, headers=headers, data=data
        )

        return cls.from_response(response)

    def _submit_form(self, data):
        headers = self.merge_headers(
            {
                "Cache-Control": "max-age=0",
                "Content-Type": Navigation.FORM_ENCODED,
                "Origin": Navigation.BASE,
                "Referer": self.url(),
                "Sec-Fetch-Dest": "iframe",
            }
        )
        return requests.post(
            Navigation.WEBSHELL_PATH,
            cookies=Navigation.COOKIES,
            headers=headers,
            data=data,
        )

    def add_start_date(self, start):
        start_date = start.strftime("%m/%d/%Y")

        data = "APPID=davlvp&CODEITEMNM=P_26&CURRPROCESS=CASELINK.MAIN&CURRVAL={start_date}&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C1&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT={parent}*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=2&CURRPANEL=1&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=4&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=P_26%7F&WCVALS={start_date}%7F".format(
            web_io_handle=self.web_io_handle,
            parent=self.parent,
            start_date=urllib.parse.quote(start_date, safe=""),
        )
        return self._submit_form(data)

    def add_detainer_warrant_type(self):
        data = "APPID=davlvp&CODEITEMNM=P_31&CURRPROCESS=CASELINK.MAIN&CURRVAL=2&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C1&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT={parent}*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=4&CURRPANEL=1&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=5&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=P_27%7FP_31%7F&WCVALS=05%2F03%2F2024%7F2%7F".format(
            web_io_handle=self.web_io_handle, parent=self.parent
        )
        return self._submit_form(data)

    def search(self):
        data = "APPID=davlvp&CODEITEMNM=WTKCB_20&CURRPROCESS=CASELINK.MAIN&CURRVAL=%A0%A0+Search+for+Case%28s%29%A0+&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C1&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT={parent}*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=4&CURRPANEL=1&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=6&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=%7F&WCVALS=%7F".format(
            web_io_handle=self.web_io_handle, parent=self.parent
        )
        return Navigation.from_response(self._submit_form(data))

    def export_csv(self):
        data = "APPID=davlvp&CODEITEMNM=WTKCB_8&CURRPROCESS=CASELINK.MAIN&CURRVAL=Export+List&DEVAPPID=&DEVPATH=%2FINNOVISION%2FDEVELOPMENT%2FLVP.DEV&FINDDEFKEY=CASELINK.MAIN&GATEWAY=PB%2CNOLOCK%2C1%2C1&LINENBR=0&NEEDRECORDS=1&OPERCODE=REDDOOR&PARENT={parent}*update&PREVVAL=&STDID=52832&STDURL=%2Fcaselink_4_4.davlvp_blank.html&TARGET=postback&WEBIOHANDLE={web_io_handle}&WINDOWNAME=update&XEVENT=POSTBACK&CHANGED=3505&CURRPANEL=2&HUBFILE=USER_SETTING&NPKEYS=0&SUBMITCOUNT=14&WEBEVENTPATH=%2FGSASYS%2FTKT%2FTKT.ADMIN%2FWEB_EVENT&WCVARS=%7F&WCVALS=%7F".format(
            web_io_handle=self.web_io_handle, parent=self.parent
        )
        return self._submit_form(data)

    def follow_url(self):
        return requests.get(self.url(), headers=self.merge_headers())
