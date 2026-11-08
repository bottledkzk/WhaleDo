"""Verify a course release HAP with the installed official Huawei signing tool."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import zipfile
from datetime import datetime, timezone

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('hap', type=Path)
parser.add_argument('--deveco-home', type=Path, default=os.environ.get('DEVECO_HOME'))
parser.add_argument('--output', type=Path)
args = parser.parse_args()
if not args.deveco_home:
    parser.error('Set DEVECO_HOME or pass --deveco-home.')
java = args.deveco_home / ('jbr/bin/java.exe' if os.name == 'nt' else 'jbr/bin/java')
signer = args.deveco_home / 'sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar'

def run(*arguments):
    result = subprocess.run([str(java), '-jar', str(signer), *map(str, arguments)], capture_output=True)
    if result.returncode:
        # Tool diagnostics can contain certificate owner metadata; do not print them.
        raise SystemExit(f'Official signing tool rejected {arguments[0]} (exit {result.returncode}).')

def certificates(pem):
    return [base64.b64decode(p) for p in re.findall(rb'-----BEGIN CERTIFICATE-----\s*(.*?)\s*-----END CERTIFICATE-----', pem, re.S)]

with tempfile.TemporaryDirectory(prefix='whaledo-verify-') as directory:
    temp = Path(directory)
    chain, profile, verification = temp/'chain.cer', temp/'profile.p7b', temp/'verification.json'
    run('verify-app', '-inFile', args.hap.resolve(), '-outCertChain', chain, '-outProfile', profile)
    run('verify-profile', '-inFile', profile, '-outFile', verification)
    verified = json.loads(verification.read_text(encoding='utf-8'))
    if verified.get('verifiedPassed') is not True:
        raise SystemExit('Profile signature verification failed.')
    content = verified['content']
    bundle = content['bundle-info']
    cert = certificates(bundle['distribution-certificate'].encode())[0]
    if cert not in certificates(chain.read_bytes()):
        raise SystemExit('Profile distribution certificate does not match the HAP certificate chain.')
    with zipfile.ZipFile(args.hap) as archive:
        module = json.loads(archive.read('module.json'))
        if archive.testzip() is not None:
            raise SystemExit('HAP archive integrity check failed.')
    app = module['app']
    if app['bundleName'] != bundle['bundle-name'] or content['type'] != 'release':
        raise SystemExit('Bundle or release Profile type mismatch.')
    if app.get('buildMode') != 'release' or app.get('debug') is not False:
        raise SystemExit('HAP must be built in release mode with debug disabled.')
    permissions = sorted(p['name'] for p in module['module']['requestPermissions'])
    acl = sorted(content.get('acls', {}).get('allowed-acls', []))
    if 'ohos.permission.READ_WHOLE_CALENDAR' in permissions and 'ohos.permission.READ_WHOLE_CALENDAR' not in acl:
        raise SystemExit('Calendar ACL is missing from the release Profile.')
    if 'ohos.permission.PUBLISH_AGENT_REMINDER' in permissions:
        raise SystemExit('Course distribution must not request the unapproved agent reminder capability.')
    device_ids = content.get('debug-info', {}).get('device-ids', [])
    if device_ids:
        raise SystemExit('Do not publish a package embedding private device identifiers.')
    now = int(datetime.now(timezone.utc).timestamp())
    validity = content['validity']
    if not validity['not-before'] <= now < validity['not-after']:
        raise SystemExit('Release Profile is not currently valid.')
    receipt = {
        'artifact': args.hap.name,
        'sha256': hashlib.sha256(args.hap.read_bytes()).hexdigest(), 'bytes': args.hap.stat().st_size,
        'bundleName': app['bundleName'], 'versionName': app['versionName'], 'versionCode': app['versionCode'],
        'buildMode': app['buildMode'], 'debug': app['debug'], 'api': app['minAPIVersion'] % 1000,
        'hapSignatureVerified': True, 'profileSignatureVerified': True, 'archiveIntegrityVerified': True,
        'certificateMatchesProfile': True, 'certificateSha256': hashlib.sha256(cert).hexdigest(),
        'profileType': content['type'], 'distributionType': content['app-distribution-type'],
        'profileExpiresUtc': datetime.fromtimestamp(validity['not-after'], timezone.utc).isoformat(),
        'permissions': permissions, 'allowedAcls': acl, 'embeddedDeviceIdentifierCount': len(device_ids),
        'universalPhysicalInstall': False, 'privateKeyIncluded': False,
        'verificationTool': 'Official DevEco Studio SDK hap-sign-tool.jar',
        'verifiedAtUtc': datetime.now(timezone.utc).isoformat()
    }
    text = json.dumps(receipt, ensure_ascii=False, indent=2) + '\n'
    if args.output:
        args.output.write_text(text, encoding='utf-8')
    print(text)
