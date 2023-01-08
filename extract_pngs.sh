#!/bin/bash

PROG_NAME=$(basename "${0}")
OUTPUT_DIR="$(pwd)/hat-kid"

MODE=''
TRIM_ENABLED=0
TRIM_N=0

check_dependencies() {
  command -v ffmpeg >/dev/null 2>&1 || { echo "Missing dependency 'ffmpeg'"; exit 1; }
}

check_dependencies

print_usage() {
cat <<EOF
Convert hat kid MP4s to PNG sequences for use with Plymouth

Usage:
  ${PROG_NAME} --mode MODE [options]

Flags:
  --mode MODE        'long' for long video, 'short' for short video
  --trim-frames N    Trim every N-th frame of the generated PNG sequence
EOF
}

if [[ ${#} -lt 2 ]]; then
  print_usage
  exit 1
fi

while (( "$#" )); do
  case "$1" in
    --mode)
      if [[ "${2}" != "long" ]] && [[ "${2}" != "short" ]]; then
        echo "Unrecognized mode '${2}'. Supported options 'long' or 'short'" >&2
        exit 1
      fi
      MODE=${2}
      shift 2
    ;;

    --trim-frames)
      TRIM_ENABLED=1
      TRIM_N=${2}
      [[ -z ${TRIM_N} ]] && { echo "When using '--trim-frames', an N value must be provided" >&2; exit 1; }
      shift 2
    ;;

    -h|--help)
      print_usage
      exit 0
    ;;

    *)
      echo "Unrecognized argument $1" >&2 
      print_usage
      exit 1
    ;;
  esac
done

if [[ -d "${OUTPUT_DIR}" ]] && [[ "$(ls -A ${OUTPUT_DIR})" ]]; then
  echo "Clearing existing throbber files from ${OUTPUT_DIR}"
  rm -I ${OUTPUT_DIR}/throbber-*.png
fi

echo "Extracting PNG frames..."
if [[ "${MODE}" == "long" ]]; then
  command ffmpeg -i ./sources/hat-kid-boot.mp4       ${OUTPUT_DIR}/throbber-%01d.png -hide_banner
else
  command ffmpeg -i ./sources/hat-kid-boot-short.mp4 ${OUTPUT_DIR}/throbber-%01d.png -hide_banner
fi

if [[ ${TRIM_ENABLED} -eq 1 ]]; then
  echo "Trimming such that I keep every ${TRIM_N}th frame"
  NUM_IMGS=$(ls -lA ${OUTPUT_DIR}/throbber-*.png | wc -l)
  # Remove the unneeded images
  for i in $(seq 1 ${NUM_IMGS}); do
    [[ $(( i % ${TRIM_N} )) -ne 0 ]] && { 
      #echo "Deleting image ${i}"; 
      rm ${OUTPUT_DIR}/throbber-${i}.png; 
    }
  done
  # Rename the leftovers to a contiguous sequence
  for i in $(seq ${TRIM_N} ${TRIM_N} ${NUM_IMGS}); do
    # echo "Renaming image ${i} to $(( i / ${TRIM_N} ))"
    mv ${OUTPUT_DIR}/throbber-${i}.png ${OUTPUT_DIR}/throbber-$(( i / ${TRIM_N} )).png
  done
fi

cat <<EOF

Extracted PNG frames are in ${OUTPUT_DIR}

Copy ${OUTPUT_DIR} to your Plymouth themes directory (i.e. /usr/share/plymouth/themes). Then, activate the theme and rebuild your initrd/initramfs. On Fedora, this should be sufficient:

$ plymouth-set-default-theme hat-kid --rebuild-initrd

EOF