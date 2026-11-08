"""Fetch the redistributable official small Chinese Vosk model for the course Android build."""
import hashlib,json,urllib.request,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
URL='https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip'
EXPECTED_SHA256='3af8b0e7e0f835ae9d414ce5df580237a3cfb08d586c9fbbb0f7ff29ad5b14ba'
DOWNLOAD=ROOT/'.tmp/android-model/vosk-model-small-cn-0.22.zip'
TARGET=ROOT/'android/app/src/main/assets/speech-model'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
DOWNLOAD.parent.mkdir(parents=True,exist_ok=True)
if not DOWNLOAD.exists():
    temporary=DOWNLOAD.with_suffix('.partial')
    with urllib.request.urlopen(urllib.request.Request(URL,headers={'User-Agent':'WhaleDo-Course-Build/0.4'}),timeout=60) as response,temporary.open('wb') as out:
        while chunk:=response.read(1024*1024):out.write(chunk)
    temporary.rename(DOWNLOAD)
receipt=DOWNLOAD.with_suffix('.json')
assert sha(DOWNLOAD)==EXPECTED_SHA256,'Official model archive hash differs from the reviewed course input'
if receipt.exists():assert sha(DOWNLOAD)==json.loads(receipt.read_text())['sha256']
with zipfile.ZipFile(DOWNLOAD) as z:
    assert z.testzip() is None
    for entry in z.infolist():
        relative=Path(*Path(entry.filename).parts[1:])
        if not relative.parts or entry.is_dir():continue
        dest=(TARGET/relative).resolve();assert dest.is_relative_to(TARGET.resolve())
        dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(entry))
metadata={'name':'vosk-model-small-cn-0.22','source':URL,'license':'Apache-2.0','sha256':sha(DOWNLOAD),'bytes':DOWNLOAD.stat().st_size}
receipt.write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
(TARGET.parent/'speech-model-source.json').write_text(json.dumps(metadata,indent=2)+'\n',encoding='utf-8')
print(json.dumps(metadata))
