BEGIN {
    sent = 0;
    recv = 0;
    delay_sum = 0;
    start_time = -1;
    end_time = 0;
    recv_data = 0;
    energy_per_bit = 0.00000005; # 50nJ per bit
}
{
    event = $1;
    time = $2;
    src = $3;
    dst = $4;
    type = $5;
    size = $6;
    seq = $11;

    if (event == "+" && type == "cbr") {
        sent++;
        send_time[seq] = time;
        pkt_size[seq] = size;
        if (start_time == -1 || time < start_time)
            start_time = time;
    }
    if (event == "-" && type == "cbr") {
        recv++;
        recv_data += size;
        delay_sum += (time - send_time[seq]);
        if (time > end_time)
            end_time = time;
    }
}
END {
    pdr = (recv / sent) * 100;
    throughput = (recv_data * 8) / (end_time - start_time) / 1000;
    avg_delay = delay_sum / recv;

    total_energy = 0;
    for (seq in send_time) {
        total_energy += pkt_size[seq] * 8 * energy_per_bit;
    }

    printf("Total Packets Sent: %d\n", sent);
    printf("Total Packets Received: %d\n", recv);
    printf("Packet Delivery Ratio (PDR): %.2f%%\n", pdr);
    printf("Throughput: %.2f kbps\n", throughput);
    printf("Average End-to-End Delay: %.6f sec\n", avg_delay);
    printf("Total Energy Consumption (J): %.6f\n", total_energy*20);
}

