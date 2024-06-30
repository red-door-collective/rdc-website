import re
import requests
from requests.adapters import HTTPAdapter
import urllib
from urllib3.util.retry import Retry
from flask import current_app

session = requests.Session()
retry = Retry(connect=3, backoff_factor=0.5)
adapter = HTTPAdapter(max_retries=retry)
session.mount("http://", adapter)
session.mount("https://", adapter)


class Navigation:

    APP_ID = "davlvp"
    BASE = "https://caselink.nashville.gov"
    BROWSER = "C*Chrome*124.0*Mac*NOBLOCKTEST"
    CASE_TYPE = "P_31"
    CGI_SCRIPT = "webshell.asp"
    FORM_ENCODED = "application/x-www-form-urlencoded"
    WEBSHELL_PATH = "/cgi-bin/webshell.asp"
    PDF_VIEWER_PATH = "/imageviewer.php"
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
    CASELINK_PROCESS = "CASELINK.MAIN"
    DATA = {"APPID": APP_ID, "CURRPROCESS": CASELINK_PROCESS}
    COOKIES = {
        "tktupdate": "",
    }
    POSTBACK_PATH_REGEX = re.compile(
        r"(?:self\.location\s*=\s*\")(.+?\.html)\"", re.MULTILINE
    )
    START_DATE_ITEM = "P_26"
    SEP = "\x7f"

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
    def merge_data(cls, data):
        return {**cls.DATA, **data}

    @classmethod
    def from_response(cls, response):
        return cls(Navigation._extract_postback_url(response))

    @classmethod
    def _username(cls):
        return current_app.config["CASELINK_USERNAME"]

    @classmethod
    def _password(cls):
        return current_app.config["CASELINK_PASSWORD"]

    @classmethod
    def login(cls, log=None):
        headers = cls.merge_headers(
            {
                "Cache-Control": "max-age=0",
                "Content-Type": cls.FORM_ENCODED,
                "Origin": cls.BASE,
                "Referer": cls._url("//davlvplogin.html?123"),
                "Sec-Fetch-Dest": "frame",
            }
        )

        data = {
            "GATEWAY": "GATEWAY",
            "CGISCRIPT": cls.CGI_SCRIPT,
            "XEVENT": "VERIFY",
            "WEBIOHANDLE": "1714928640773",
            "BROWSER": cls.BROWSER,
            "MYPARENT": "px",
            "APPID": cls.APP_ID,
            "WEBWORDSKEY": "SAMPLE",
            "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
            "OPERCODE": cls._username(),
            "PASSWD": cls._password(),
        }

        response = session.post(
            cls.webshell(), cookies=cls.COOKIES, headers=headers, data=data
        )

        if log is not None:
            log.append({"name": "login", "response": response})

        return cls.from_response(response)

    def _submit_form(self, data, headers=None):
        merged_headers = self.merge_headers(
            {
                "Cache-Control": "max-age=0",
                "Content-Type": Navigation.FORM_ENCODED,
                "Origin": Navigation.BASE,
                "Referer": self.url(),
                "Sec-Fetch-Dest": "iframe",
            }
        )
        return session.post(
            self.webshell(),
            cookies=Navigation.COOKIES,
            headers={**merged_headers, **headers} if headers else merged_headers,
            data=data,
        )

    @classmethod
    def _date(cls, date):
        return date.strftime("%m/%d/%Y")

    @classmethod
    def _format_date(cls, date):
        return cls.escape(cls._date(date))

    @classmethod
    def escape(cls, str):
        return urllib.parse.quote(str, safe="")

    @classmethod
    def _encode_data(self, data):
        return urllib.parse.urlencode(data, safe="*")

    def add_start_date(self, start):
        start_date = Navigation._date(start)
        data = self.merge_data(
            {
                "CODEITEMNM": self.START_DATE_ITEM,
                "CURRVAL": start_date,
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": "CASELINK.MAIN",
                "GATEWAY": "PB,NOLOCK,1,1",
                "LINENBR": "0",
                "NEEDRECORDS": "1",
                "OPERCODE": self._username(),
                "PARENT": "STDHUB*update",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "POSTBACK",
                "CHANGED": "2",
                "CURRPANEL": "1",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "4",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
                "WCVARS": self.START_DATE_ITEM + self.SEP,
                "WCVALS": start_date + self.SEP,
            }
        )
        return self._submit_form(
            self._encode_data(data),
            headers={
                "Host": "caselink.nashville.gov",
                "Accept-Encoding": "gzip, deflate, br, zstd",
            },
        )

    def add_detainer_warrant_type(self, end):
        end_date = Navigation._date(end)
        data = self.merge_data(
            {
                "CODEITEMNM": self.CASE_TYPE,
                "CURRVAL": "2",
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": self.CASELINK_PROCESS,
                "GATEWAY": "PB,NOLOCK,1,1",
                "LINENBR": "0",
                "NEEDRECORDS": "1",
                "OPERCODE": self._username(),
                "PARENT": "STDHUB*update",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "POSTBACK",
                "CHANGED": "4",
                "CURRPANEL": "1",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "5",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
                "WCVARS": "P_27{sep}P_31{sep}".format(sep="\x7f"),
                "WCVALS": "{end_date}{sep}{warrant_filter}{sep}".format(
                    end_date=end_date,
                    warrant_filter="2",
                    sep="\x7f",
                ),
            }
        )

        return self._submit_form(
            self._encode_data(data), headers={"Host": "caselink.nashville.gov"}
        )

    def search(self):
        data = self.merge_data(
            {
                "CODEITEMNM": "WTKCB_20",
                "CURRVAL": "�� Search for Case(s)� ",
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": self.CASELINK_PROCESS,
                "GATEWAY": "PB,NOLOCK,1,1",
                "LINENBR": "0",
                "NEEDRECORDS": "1",
                "OPERCODE": self._username(),
                "PARENT": "STDHUB*update",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "POSTBACK",
                "CHANGED": "4",
                "CURRPANEL": "1",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "6",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
                "WCVARS": "\x7f",
                "WCVALS": "\x7f",
            }
        )
        return self._submit_form(self._encode_data(data))

    def search_update(self, cell_names, wc_vars, wc_values):
        data = self.merge_data(
            {
                "CODEITEMNM": "P_102_1",
                "CURRPROCESS": "CASELINK.MAIN",
                "CURRVAL": "24GT4771",
                "PREVVAL": "�CLICK",
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": "CASELINK.MAIN",
                "GATEWAY": "PB,NOLOCK,1,0",
                "LINENBR": "0",
                "NEEDRECORDS": "1",
                "OPERCODE": self._username(),
                "PARENT": "STDHUB*update",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "POSTBACK",
                "CHANGED": str(len(cell_names) + 1),
                "CURRPANEL": "2",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "7",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
                "WCVARS": wc_vars,
                "WCVALS": wc_values,
            }
        )
        return self._submit_form(self._encode_data(data))

    def follow_url(self):
        return session.get(
            self.url(),
            cookies=Navigation.COOKIES,
            headers=self.merge_headers(
                {"Referer": self.url(), "Sec-Fetch-Dest": "frame"}
            ),
        )

    def menu(self):
        data = self.merge_data(
            {
                "CURRPROCESS": "CASELINK.ADMIN",
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": self.CASELINK_PROCESS,
                "GATEWAY": "WIN*CASELINK.ADMIN",
                "LINENBR": "0",
                "OPERCODE": "REDDOOR",
                "PARENT": "MENU",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "STDHUB",
            }
        )

        return self._submit_form(self._encode_data(data))

    def read_rec(self):
        data = self.merge_data(
            {
                "CURRVAL": "1",
                "DEVPATH": "/INNOVISION/DEVELOPMENT/LVP.DEV",
                "FINDDEFKEY": self.CASELINK_PROCESS,
                "GATEWAY": "FL",
                "LINENBR": "0",
                "NEEDRECORDS": "-1",
                "OPERCODE": "REDDOOR",
                "PARENT": "STDHUB*update",
                "PREVVAL": "0",
                "STDID": "52832",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "postback",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "READREC",
                "CHANGED": "0",
                "CURRPANEL": "1",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "2",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
            }
        )

        return self._submit_form(self._encode_data(data))

    def open_case(self, code_item, docket_id, cell_names, wc_vars, wc_vals):
        data = self.merge_data(
            {
                "APPID": "pubgs",
                "CODEITEMNM": code_item,
                "CURRVAL": docket_id,
                "DEVPATH": "/INNOVISION/DAVIDSON/PUB.SESSIONS",
                "FINDDEFKEY": "LVP.SES.INQUIRY",
                "GATEWAY": "CP*CASELINK.MAIN",
                "LINENBR": "1",
                "NEEDRECORDS": "0",
                "OPERCODE": "REDDOOR",
                "PARENT": "STDHUB*update",
                "PREVVAL": "�CLICK",
                "STDID": "24GT4771",
                "STDURL": "/caselink_4_4.davlvp_blank.html",
                "TARGET": "_self",
                "WEBIOHANDLE": self.web_io_handle,
                "WINDOWNAME": "update",
                "XEVENT": "STDHUB",
                "CHANGED": str(len(cell_names) - 1),
                "CURRPANEL": "2",
                "HUBFILE": "USER_SETTING",
                "NPKEYS": "0",
                "SUBMITCOUNT": "8",
                "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
            }
        )

        return self._submit_form(
            self._encode_data(data),
            headers={
                "Host": "caselink.nashville.gov",
                "Accept-Encoding": "gzip, deflate, br, zstd",
            },
        )

    @classmethod
    def _encode(cls, string):
        return urllib.parse.quote(string, safe="")

    def open_case_redirect(self, docket_id):
        data = {
            "APPID": "pubgs",
            "CURRPROCESS": "LVP.SES.INQUIRY",
            "CURRVAL": "1",
            "DEVPATH": "/INNOVISION/DAVIDSON/PUB.SESSIONS",
            "FINDDEFKEY": "LVP.SES.INQUIRY",
            "GATEWAY": "FL",
            "LINENBR": "0",
            "NEEDRECORDS": "-1",
            "OPERCODE": self._username(),
            "PARENT": "STDHUB*update",
            "PREVVAL": "0",
            "STDID": docket_id,
            "STDURL": "/caselink_4_4.davlvp_blank.html",
            "TARGET": "postback",
            "WEBIOHANDLE": self.web_io_handle,
            "WINDOWNAME": "update",
            "XEVENT": "READREC",
            "CHANGED": "0",
            "CURRPANEL": "1",
            "HUBFILE": "TRANS",
            "NPKEYS": "0",
            "SUBMITCOUNT": "2",
            "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
        }

        return self._submit_form(data)

    def open_pleading_document_redirect(self, docket_id):
        data = {
            "APPID": "pubgs",
            "CODEITEMNM": "WTKCB_21_1",
            "CURRPROCESS": "LVP.SES.INQUIRY",
            "CURRVAL": "   View Image   ",
            "DEVPATH": "/INNOVISION/DAVIDSON/PUB.SESSIONS",
            "FINDDEFKEY": "LVP.SES.INQUIRY",
            "GATEWAY": "PB,NOLOCK,1,1",
            "LINENBR": "0",
            "NEEDRECORDS": "1",
            "OPERCODE": "REDDOOR",
            "PARENT": "STDHUB*update",
            "STDID": docket_id,
            "STDURL": "/caselink_4_4.davlvp_blank.html",
            "TARGET": "postback",
            "WEBIOHANDLE": self.web_io_handle,
            "WINDOWNAME": "update",
            "XEVENT": "POSTBACK",
            "CHANGED": "0",
            "CURRPANEL": "1",
            "HUBFILE": "TRANS",
            "NPKEYS": "0",
            "SUBMITCOUNT": "3",
            "WEBEVENTPATH": "/GSASYS/TKT/TKT.ADMIN/WEB_EVENT",
            "WCVARS": "P_326_1\x7fTOTAL_P_326\x7fTOTAL_P_327\x7fTOTAL_P_328\x7fTOTAL_P_329\x7fTOTAL_P_330\x7fTOTAL_P_331\x7fTOTAL_P_332\x7fTOTAL_P_333\x7fTOTAL_P_334\x7fTOTAL_P_335\x7fTOTAL_P_336\x7fTOTAL_P_337\x7fTOTAL_P_326\x7f",
            "WCVALS": "61.75\x7f61.75\x7f44.00\x7f17.75\x7f0.00\x7f0.00\x7f0.00\x7f0.00\x7f0.00\x7f0.00\x7f0.00\x7f0.00\x7f0.00\x7f61.75\x7f",
        }

        return self._submit_form(data)

    def view_pdf(self, image_path):
        data = "image={image_path}".format(image_path=self._encode(image_path))

        return session.post(
            self._url(Navigation.PDF_VIEWER_PATH),
            cookies=Navigation.COOKIES,
            headers=self.merge_headers(
                {
                    "Cache-Control": "max-age=0",
                    "Content-Type": Navigation.FORM_ENCODED,
                    "Origin": Navigation.BASE,
                    "Referer": self.url(),
                    "Sec-Fetch-Dest": "iframe",
                    "Sec-Fetch-Dest": "document",
                }
            ),
            data=data,
        )
