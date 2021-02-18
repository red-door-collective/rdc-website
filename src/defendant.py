class Defendant:
    name: str
    phone: str
    address: str

    def __init__(self, **kwargs) -> None:
        self.name = kwargs['name']
        self.phone = kwargs['phone']
        self.address = kwargs['address']
