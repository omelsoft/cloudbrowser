# Gnuplot script file for plotting data
reset
set terminal png
set samples 10000
set   autoscale                        # scale axes automatically
unset log                              # remove any log-scaling
unset label                            # remove any previous labels
set xtic auto                          # set xtics automatically
set ytic auto                          # set ytics automatically
set title "System Resource Usage ".filename
set xlabel "Time(ms)"
set ylabel "Usage"

set ylabel "percentage"
set y2label "MB"

set ytics nomirror in
set y2tics nomirror

set yrange [0:*]
set y2range [0:*]

# filename is a parameter
plot filename u 1:2 t 'cpu(%)' w linespoints axes x1y1,\
"" u 1:3 t 'memory(MB)' w linespoints axes x1y2
#