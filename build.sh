#!/bin/bash

mkdir -p /tmp/rom
cd /tmp/rom

git config --global user.name Chandler
git config --global user.email chhandler_bing@gmail.com

export rom=Descendant

rom_one(){
 repo init -u https://github.com/descendant-oss/manifest -b eleven-staging -g default,-device,-mips,-darwin,-notdefault
 repo sync --no-tags --no-clone-bundle --current-branch --force-sync --optimized-fetch -j16
 git clone https://github.com/geopd/device_xiaomi_sakura -b dot-11 device/xiaomi/sakura
 git clone https://github.com/geopd/vendor_xiaomi_sakura -b lineage-18.1 vendor/xiaomi
 . build/envsetup.sh && lunch descendant_sakura-userdebug
 
}

rom_two(){
 repo init --no-repo-verify -u https://github.com/Evolution-X/manifest -b elle -g default,-device,-mips,-darwin,-notdefault
 repo sync --no-tags --no-clone-bundle --current-branch --force-sync --optimized-fetch -j16
 git clone https://$TOKEN@github.com/geopd/device_xiaomi_sakura_TEST.git -b elle device/xiaomi/sakura
 git clone https://$TOKEN@github.com/geopd/vendor_xiaomi_sakura_TEST.git -b lineage-18.0 vendor/xiaomi
 rm -rf vendor/gms && git clone https://gitlab.com/geopdgitlab/vendor_gapps -b eleven vendor/gms
 . build/envsetup.sh && lunch evolution_sakura-userdebug
}

rom_three(){
 repo init --no-repo-verify -u git://github.com/DotOS/manifest.git -b dot11 -g default,-device,-mips,-darwin,-notdefault
 repo sync --no-tags --no-clone-bundle --current-branch --force-sync --optimized-fetch -j16
 git clone https://$TOKEN@github.com/geopd/device_xiaomi_sakura_TEST.git -b dot-R device/xiaomi/sakura
 git clone https://$TOKEN@github.com/geopd/vendor_xiaomi_sakura_TEST.git -b lineage-18.1 vendor/xiaomi
 rm -rf hardware/qcom-caf/msm8996/audio hardware/qcom-caf/msm8996/display hardware/qcom-caf/msm8996/media
 git clone https://github.com/Jabiyeff-Project/android_hardware_qcom_audio -b 11.0 hardware/qcom-caf/msm8996/audio
 git clone https://github.com/Jabiyeff-Project/android_hardware_qcom_display -b 11.0 hardware/qcom-caf/msm8996/display
 git clone https://github.com/Jabiyeff-Project/android_hardware_qcom_media -b 11.0 hardware/qcom-caf/msm8996/media
 . build/envsetup.sh && lunch dot_sakura-userdebug
 mka descendant
}

git clone https://$TOKEN@github.com/geopd/kernel_xiaomi_msm8953 -b beta-4.9-Q kernel/xiaomi/msm8953 
git clone https://github.com/geopd/vendor_custom_prebuilts -b master vendor/custom/prebuilts
git clone https://github.com/mvaisakh/gcc-arm64.git -b gcc-master prebuilts/gcc/linux-x86/aarch64/aarch64-elf

case "$rom" in
 "dotOS") rom_one
    ;;
 "EvolutionX") rom_two
    ;;
 "dotOS-R") rom_three
    ;;
 *) echo "Invalid option!"
    exit 1
    ;;
esac

BUILD_DATE=$(date +"%Y%m%d")
BUILD_START=$(date +"%s")

telegram_message() {
    curl -s -X POST "https://api.telegram.org/bot$BOTTOKEN/sendMessage" -d chat_id="$CHATID" \
    -d "parse_mode=html" \
    -d text="$1"
}

telegram_message "<b>🌟 $rom Build Triggered 🌟</b>%0A%0A<b>Date: </b><code>$(TZ=Asia/Kolkata date +"%d-%m-%Y %T")</code>"

export CCACHE_DIR=/tmp/ccache
export CCACHE_EXEC=$(which ccache)
export USE_CCACHE=1
ccache -M 20G && ccache -o compression=true && ccache -z
make api-stubs-docs && make system-api-stubs-docs && make test-api-stubs-docs

case "$rom" in
 "dotOS") make bacon -j20
    ;;
 "EvolutionX") mka bacon -j20
    ;;
 "dotOS-R") make bacon -j20
    ;;
 *) echo "Invalid option!"
    exit 1
    ;;
esac

BUILD_END=$(date +"%s")
DIFF=$((BUILD_END - BUILD_START))

telegram_build() {
 curl --progress-bar -F document=@"$1" "https://api.telegram.org/bot$BOTTOKEN/sendDocument" \
 -F chat_id="$CHATID" \
 -F "disable_web_page_preview=true" \
 -F "parse_mode=Markdown" \
 -F caption="$2"
}

telegram_post(){
 if [ -f $(pwd)/out/target/product/sakura/*sakura*"${BUILD_DATE}"*.zip ]; then
	curl -sL https://git.io/file-transfer | sh
	ZIP="$(echo "$(pwd)/out/target/product/sakura/*sakura*"${BUILD_DATE}"*.zip")"
	MD5CHECK=$(md5sum $ZIP | cut -d' ' -f1)
	WET=$(echo "./transfer wet $ZIP")
	ZIPNAME=$(echo "$($WET |  cut -s -d'/' -f 8)")
	DWD=$(echo "$($WET | sed '$!d' | cut -d' ' -f3)")
	telegram_message "<b>✅ Build finished after $((DIFF / 3600)) hour(s), $((DIFF % 3600 / 60)) minute(s) and $((DIFF % 60)) seconds</b>%0A%0A<b>ROM: </b><code>$ZIPNAME</code>%0A%0A<b>MD5 Checksum: </b><code>$MD5CHECK</code>%0A<b>Download Link: </b><code>$DWD</code>%0A%0A<b>Date: </b><code>$(TZ=Asia/Kolkata date +"%d-%m-%Y %T")</code>"
 else
	LOG="$(echo "$(pwd)/out/build_error")"
	telegram_build $LOG "*❌ Build failed to compile after $(($DIFF / 3600)) hour(s) and $(($DIFF % 3600 / 60)) minute(s) and $(($DIFF % 60)) seconds*
	_Date:  $(TZ=Asia/Kolkata date +"%d-%m-%Y %T")_"
 fi
}

telegram_post
