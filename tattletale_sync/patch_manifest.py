#!/usr/bin/env python3
"""Patches the generated Flutter AndroidManifest.xml with the permissions
and service declarations needed by Tattletale Sync."""
import sys

def patch(path):
    with open(path, 'r') as f:
        content = f.read()

    permissions = (
        '    <uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n'
        '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>\n'
        '    <uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"/>\n'
        '\n'
    )

    service_receiver = (
        '\n'
        '        <service\n'
        '            android:name="id.flutter.flutter_background_service.BackgroundService"\n'
        '            android:exported="false"/>\n'
        '\n'
        '        <receiver\n'
        '            android:name="id.flutter.flutter_background_service.BackgroundServiceOnBootReceiver"\n'
        '            android:exported="true">\n'
        '            <intent-filter>\n'
        '                <action android:name="android.intent.action.BOOT_COMPLETED"/>\n'
        '            </intent-filter>\n'
        '        </receiver>\n'
    )

    # Insert permissions before <application
    content = content.replace('<application', permissions + '    <application', 1)
    # Insert service + boot receiver before </application>
    content = content.replace('</application>', service_receiver + '    </application>', 1)

    with open(path, 'w') as f:
        f.write(content)

    print('AndroidManifest.xml patched successfully.')

if __name__ == '__main__':
    patch(sys.argv[1])
