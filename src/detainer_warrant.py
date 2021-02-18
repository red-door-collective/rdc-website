from types import List
from defendant import Defendant

class DetainerWarrant:
    docket_id: str
    file_date: str
    status: str # union?
    plantiff: str
    plantiff_attorney: str
    court_date: str # date
    courtroom: str
    presiding_judge: str
    amount_claimed: str # USD
    amount_claimed_category: str # enum (POSS | FEES | BOTH | NA)
    defendant_address: str
    defendant_name: str
    defendant_phone: str
    defendant2_name: str
    defendant2_phone: str
    defendant3_name: str
    defendant3_phone: str
    judgement: str

    def __init__(self, **kwargs) -> None:
        self.docket_id = kwargs['docket_id']
        self.file_date = kwargs['file_date']
        self.status = kwargs['status']
        self.plantiff = kwargs['plantiff']
        self.plantiff_attorney = kwargs['plantiff_attorney']
        self.court_date = kwargs['court_date']
        self.presiding_judge = kwargs['presiding_judge']
        self.amount_claimed = kwargs['amount_claimed']
        self.amount_claimed_category = kwargs['amount_claimed_category']
        self.defendant_address = kwargs['defendant_address']
        self.defendant_name = kwargs['defendant_name']
        self.defendant2_name = kwargs['defendant2_name']
        self.defendant2_phone = kwargs['defendant2_phone']
        self.defendant3_name = kwargs['defendant3_name']
        self.defendant3_phone = kwargs['defendant3_phone']
        self.judgement = kwargs['judgement']

    def defendants(self) -> List[Defendant]:
        defendant1 = Defendant(name=self.defendant_name, phone=self.defendant_phone, address=self.defendant_address)
        defendant2 = None
        defendant3 = None
        if self.defendant2_name or self.defendant2_phone:
            defendant2 = Defendant(name=self.defendant2_name, phone=self.defendant2_phone)
        if self.defendant3_name or self.defendant3_phone:
            defendant3 = Defendant(name=self.defendant3_name, phone=self.defendant3_phone)

        return [defendant1, defendant2, defendant3]
