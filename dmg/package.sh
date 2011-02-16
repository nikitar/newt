rm -r data/Newt.app
cp -r ../build/Release/Newt.app data

test -f Newt.dmg && rm Newt.dmg
rm /var/folders/3d/3dc7a4MoF0egsCXnE1tJgk+++TI/-Tmp-/createdmg
./create-dmg --window-size 300 350 --icon-size 64 --volname "Newt" \
--icon "Newt" 50 50 \
--icon "Applications" 200 50 \
--icon "Read Me.webloc" 50 200 \
--icon "Install Growl.webloc" 200 200 \
../build/Newt-2_0.dmg ./data/ 

rm -r data/Newt.app