BEGIN {
    FS = " ";
    OFS = ",";  # Use comma as output field separator
    print "Time,NodeID,TrafficLoad,PacketReceived,ResidualEnergy,DistanceToBS,EnergyDrainRate,PacketSuccessRate";
   
    # Initialize values
    for (i = 0; i < 100; i++) {
        initial_energy[i] = 100;  
        residual_energy[i] = 100;
        prev_energy[i] = 100;
        prev_packets[i] = 0;
    }
}

# Track sent packets (+ event means a packet was sent)
$1 == "+" {
    nodeID = $3;
    traffic[nodeID] += 1;
    residual_energy[nodeID] -= 0.01;  # Energy consumption
}

# Track received packets at Base Station (r event)
$1 == "r" {
    nodeID = $3;
    received[nodeID] += 1;
}

# Compute distance to BS (BS at (250,250))
/[0-9]+\.[0-9]+/ {
    nodeID = $3;
    x = $9;
    y = $10;
    dx = x - 250;
    dy = y - 250;
    distance_to_bs[nodeID] = sqrt(dx*dx + dy*dy);
}

# Compute Energy Drain Rate and Packet Success Rate every 1s
$2 ~ /^[0-9]+(\.[0-9]+)?$/ {
    energy_drain_rate = (prev_energy[nodeID] - residual_energy[nodeID]) / 1.0;
    packet_success_rate = received[nodeID] / (traffic[nodeID] + 0.01);  # Avoid divide by zero

    print $2, nodeID, traffic[nodeID], received[nodeID], residual_energy[nodeID], distance_to_bs[nodeID], energy_drain_rate, packet_success_rate;

    prev_energy[nodeID] = residual_energy[nodeID];
    prev_packets[nodeID] = received[nodeID];
}

