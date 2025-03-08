# Initialize NS2 Simulator
set ns [new Simulator]

# Create Trace and NAM files
set tracefile [open wired.tr w]
$ns trace-all $tracefile

# Open a file to store SINR values
set sinr_tracefile [open sinr_results.tr w]

set namfile [open wired.nam w]
$ns namtrace-all $namfile

# Define Node Colors
$ns color 1 Black    ;# Normal Nodes
$ns color 2 Green    ;# Cluster Heads
$ns color 3 Blue     ;# Base Station
$ns color 4 Yellow   ;# Eavesdropper
$ns color 5 Purple   ;# Jamming Signal

# Create 10 Normal Nodes
set nodes {}
for {set i 0} {$i < 10} {incr i} {
    set node($i) [$ns node]
    $node($i) color Black
    lappend nodes $node($i)
}

# Define Base Station (BS)
set bs [$ns node]
$bs color Blue

# Select Random Cluster Heads (CHs)
set ch1 $node([expr {int(rand() * 10)}])
set ch2 $node([expr {int(rand() * 10)}])
$ch1 color Green
$ch2 color Green

# Define Eavesdroppers (Only linked to CHs)
set eav1 [$ns node]
set eav2 [$ns node]
$eav1 color Yellow
$eav2 color Yellow

# Create Links (Cluster Heads → Base Station)
$ns duplex-link $ch1 $bs 2Mb 10ms DropTail
$ns duplex-link $ch2 $bs 2Mb 10ms DropTail

# Assign Nodes to Cluster Heads and Establish Links
foreach n $nodes {
    if {$n != $ch1 && $n != $ch2} {
        set rand_ch [expr {int(rand() * 2)}]
        if {$rand_ch == 0} {
            set cluster($n) $ch1
        } else {
            set cluster($n) $ch2
        }
        $ns duplex-link $n $cluster($n) 1Mb 5ms DropTail
    }
}

# Eavesdroppers only linked to Cluster Heads
$ns duplex-link $eav1 $ch1 1Mb 5ms DropTail
$ns duplex-link $eav2 $ch2 1Mb 5ms DropTail

# Select Random Normal Nodes to Act as Jammers
set jam1 $node([expr {int(rand() * 10)}])
set jam2 $node([expr {int(rand() * 10)}])
while {$jam1 == $ch1 || $jam1 == $ch2 || $jam1 == $eav1 || $jam1 == $eav2} {
    set jam1 $node([expr {int(rand() * 10)}])
}
while {$jam2 == $ch1 || $jam2 == $ch2 || $jam2 == $eav1 || $jam2 == $eav2 || $jam2 == $jam1} {
    set jam2 $node([expr {int(rand() * 10)}])
}

# Jamming Mechanism using Normal Nodes as Jammers
proc activate_jamming {jam eav ch} {
    global ns
    
    $ns at 1.5 "$jam color Purple"
    $ns at 1.5 "$eav color Red"
    $ns rtmodel-at 1.5 down $eav $ch
    
    set udp [new Agent/UDP]
    set cbr [new Application/Traffic/CBR]
    $cbr attach-agent $udp
    $ns attach-agent $jam $udp

    set sink [new Agent/Null]
    $ns attach-agent $eav $sink
    $ns connect $udp $sink

    $cbr set packetSize_ 1024
    $cbr set interval_ 0.001

    $ns at 1.5 "$cbr start"
    $ns at 2.0 "$cbr stop"

    $ns at 2.0 "$jam color Black"
    $ns at 2.0 "$eav color Yellow"
    $ns rtmodel-at 2.0 up $eav $ch
}

activate_jamming $jam1 $eav1 $ch1
activate_jamming $jam2 $eav2 $ch2

# SINR Calculation and Logging with Timestamps
proc calculate_SINR {node interferer noise} {
    global sinr_tracefile ns
    set timestamp [$ns now]
    
    set P_signal [expr rand() * 10]
    set P_interference [expr rand() * 5]
    set P_noise [expr rand() * $noise]

    set SINR [expr $P_signal / ($P_interference + $P_noise)]
    puts "Time: $timestamp, Node: $node, Interferer: $interferer, SINR: $SINR dB"
    puts $sinr_tracefile "Time: $timestamp, Node: $node, Interferer: $interferer, SINR: $SINR dB"
}

# Schedule SINR Calculation at Regular Intervals
proc schedule_SINR {ns nodes_list} {
    global sinr_log_interval
    set sinr_log_interval 0.1  ;# Log every 0.1s

    foreach n $nodes_list {
        foreach i $nodes_list {
            if {$n != $i} {
                calculate_SINR $n $i 0.1
            }
        }
    }
    $ns at [expr [$ns now] + $sinr_log_interval] "schedule_SINR $ns \"$nodes_list\""
}

schedule_SINR $ns "$nodes"

# CBR Traffic from Normal Nodes to Cluster Heads
foreach n $nodes {
    if {$n != $ch1 && $n != $ch2} {
        set udp [new Agent/UDP]
        set cbr [new Application/Traffic/CBR]
        $cbr attach-agent $udp

        $ns attach-agent $n $udp
        set sink [new Agent/Null]
        $ns attach-agent $cluster($n) $sink

        $ns connect $udp $sink

        $cbr set packetSize_ 512
        $cbr set interval_ 0.01

        $ns at 0.1 "$cbr start"
    }
}

# Start Simulation and Finish Process
$ns at 10.0 "finish"

proc finish {} {
    global ns tracefile namfile sinr_tracefile
    close $tracefile
    close $namfile
    close $sinr_tracefile
    puts "Simulation Completed!"
    exit 0
}

$ns run

