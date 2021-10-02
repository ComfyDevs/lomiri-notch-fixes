#!/bin/bash
set -e

if [ $UID -eq 0 ]; then
	echo ">> ERROR: Please run this script as the regular user 'phablet'!"
	exit 1
fi

WORK="$HOME/.cache/lomiri-notch-fixes"
DEVICE="$1"

if [ -z "$DEVICE" ]; then
	DEVICE="$(getprop ro.product.device)" # e.g. 'yggdrasil'
	if [ "$(getprop ro.product.device)" = "merlinnfc" -o "$(getprop ro.product.device)" = "merlinx" ]; then
		DEVICE="merlinn"
	fi
fi

if [ "$DEVICE" = "halium_arm64" ]; then
	DEVICE="$(getprop ro.product.vendor.device)" # e.g. 'OnePlus6'
	if [ "$(getprop ro.product.vendor.device)" = "merlinnfc" -o "$(getprop ro.product.vendor.device)" = "merlinx" ]; then
		DEVICE="merlin"
	fi
fi

echo ">> Device is '$DEVICE'"

DIFF="$WORK/$DEVICE.diff"


if [ ! -e $DIFF ]; then
	mkdir -p $WORK
	fetchPatches(){
		echo ">> Fetching patches for $DEVICE..."
		if ! wget -O $DIFF https://raw.githubusercontent.com/ComfyDevs/lomiri-notch-fixes/main/patches/$DEVICE.diff; then
			echo "ERROR: There isn't a patch for your device ($DEVICE)"
			echo "If you believe this is wrong, or want to request a patch for your device, create an issue on github"
			echo "Alternatively, you can use a patch for another device that might work on yours"
			getdeviceandfetchpatches(){
				read -p "What device? " ans
				DEVICE="$(echo '$ans' | tr '[:upper:]' '[:lower:]')"
				fetchPatches
			}
			read -p "Use another device's patch? (y/N) " ans
			[[ "${ans^^}" = "Y"* ]] && \
				getdeviceandfetchpatches || \
				exit 1
				
			fi

		fi
	}
	fetchPatches
fi

if ! hash patch 2>/dev/null; then
	echo ">> System utility 'patch' not found, starting installation..."
	mount | grep -q ' / .*ro' && sudo mount -o remount,rw /
	sudo cat /dev/null
	sudo apt update -yqq > /dev/null
	sudo apt install -yqq patch > /dev/null
fi

echo ">> Copying system files to patch & checking compatability..."
cd $WORK
for file in $(grep '^diff' $DIFF | grep -Eo '\ b/.*' | cut -c 4-); do
	mkdir -p $(dirname $WORK/root/$file)
	cp /$file $WORK/root/$file
done

cd root/
if ! patch -p1 < $DIFF; then
	echo ">> ERROR: Some system files are incompatible with the patches;
          Please adjust '$DEVICE.diff' and try again!"
	exit 1
fi
cd ../

echo ">> Patches applied successfully! Proceeding to replacing system files..."
mount | grep -q ' / .*ro' && sudo mount -o remount,rw /
sudo cp -r root/* /
sudo mount -o remount,ro /

read -p ">> All done, would you like to restart unity8 right now (Y/n)? " ans
[[ -z "$ans" || "${ans^^}" = "Y"* ]] && \
	initctl restart unity8 || \
	echo ">> Please reboot later for the changes to take effect!"
rm -r $WORK/root/
