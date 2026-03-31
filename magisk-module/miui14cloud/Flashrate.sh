# !/system/bin/sh
# Way to get fps and display
wide=$(dumpsys display | grep 'DisplayModeRecord' | cut -d , -f 2)
flashrate=$(dumpsys display | grep 'DisplayModeRecord' | cut -d , -f 4| cut -d . -f 1)

# Initialize the variable
backdoor=-1;tmp=0;widthmax=0;fpsmax=0

# Get max fps
for i in $flashrate; do eval $i; echo $fps;[ $fps -ge $fpsmax ] && let fpsmax=$fps; done

# Get surfacefingerbackdoor gears with max fps
for i in $flashrate; do
    eval $i
    let backdoor++
    [ $fps -eq $fpsmax ] && backdoorfps[$tmp]=$backdoor && let tmp++
done
tmp=0
echo "fpsmax:$fpsmax"
echo "backdoorfps:${backdoorfps[*]}"
backdoor=-1

# Get max width
for i in $wide; do eval $i; echo $width; [ $width -ge $widthmax ] && let widthmax=$width
done

# Get surfacefingerbackdoor gears with max width
for i in $wide; do
    eval $i
    let backdoor++
    [ $width -eq $widthmax ] && backdoorwid[$tmp]=$backdoor && let tmp++
done
echo "max:$widthmax"
echo "backdoorwid:${backdoorwid[*]}"

# Match the gear with the highest fps and resolution, and use surfacefingerbackdoor to set it
let mwid=${#backdoorwid[*]}-1
let mfps=${#backdoorfps[*]}-1
for i in $(seq 0 1 $mwid); do
    tmp=${backdoorwid[i]}
    for u in $(seq 0 1 $mfps); do
        [ ${backdoorwid[$tmp]} -eq ${backdoorfps[$u]} ] && service call SurfaceFlinger 1035 i32 ${backdoorfps[$u]} && echo "Exec service call SurfaceFlinger 1035 i32 ${backdoorfps[$u]}"
    done
done
#exit 0