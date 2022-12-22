# SPDX-License-Identifier: MPL-2.0

start_time=""
end_time=""

_runtime_calc(){
	set +e
	case $1 in
		start)
			start_time="$(date +%s)"
			printf "Operation started at $(date --date=@$start_time)\n\n"
			;;
		stop)
			end_time="$(date +%s)"
			runtime="$(expr $end_time - $start_time)"
			hours="$(expr $runtime / 3600)"
			minutes=0
			printf "Operation took "

			if [ $hours -ne 0 ]; then
				printf "$hours hours"
				runtime="$(expr $runtime - $(expr $hours '*' 3600))"
				if [ $runtime -gt 60 ]; then
					printf ", "
				else
					printf " and "
				fi
			fi
			minutes="$(expr $runtime / 60)"

			if [ $minutes -ne 0 ]; then
				printf "$minutes minutes and "
				runtime="$(expr $runtime - $(expr $minutes '*' 60))"
			fi

			echo "$runtime seconds to complete"
			;;
	esac
	set -e
}
