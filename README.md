# Groovelet

Groovelet is a music player for the iPhone 4S on iOS 6.1.3 (jailbroken).
It plays local audio files on the phone. It has a modern look, but it stays
light and fast on the A5 chip. You install it as a .deb package through
Cydia.

## Get the SDK

1. Download `iPhoneOS9.3.sdk.tar.xz` from the releases of
   <https://github.com/theos/sdks>.
2. Unpack it into `sdks/`. The result is `sdks/iPhoneOS9.3.sdk`.
3. Run the fix script one time:

       ./fix-sdk.sh

The SDK is third-party. Git does not track `sdks/`.

## Build

    ./build.sh OUT SRC.m -framework Foundation

The script makes an armv7 binary in ARM mode for iOS 6. It compiles with
ARC and links without ARC.

## Run on the phone

The phone is at `iphone4s` over a USB iproxy tunnel on port 2222.

    scp OUT iphone4s:/tmp/
    ssh iphone4s 'ldid -S /tmp/OUT && /tmp/OUT'
