from setuptools import setup, find_packages

setup(
    name='eviction-tracker',
    version='0.1',
    packages=find_packages(),
    py_modules=['config'],
    zip_safe=False,
    entry_points={
        'console_scripts': ['app = app:app.run']
    },
)
