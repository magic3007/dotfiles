import requests
import getpass

url = "https://its4.pku.edu.cn/cas/ITSClient"
username = input('username: ')
password = getpass.getpass('password: ')
payload = {
      'username': username,
      'password': password,
      'iprange': 'free',
      'cmd': 'open'
}
headers = {'Content-type': 'application/x-www-form-urlencoded'}
result = requests.post(url, params=payload, headers=headers)
print(result.text)
