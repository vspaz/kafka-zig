const librdkafka = @cImport({
    @cInclude("librdkafka/rdkafka.h");
});
const std = @import("std");
const config = @import("config.zig");
const assert = std.debug.assert;

pub const Producer = struct {
    _producer: ?*librdkafka.rd_kafka_t,
    _topic: ?*librdkafka.rd_kafka_topic_t = undefined,

    pub fn init(conf: ?*librdkafka.struct_rd_kafka_conf_s, topic: [*]const u8) Producer {
        const kafka_producer: ?*librdkafka.rd_kafka_t = librdkafka.rd_kafka_new(librdkafka.RD_KAFKA_PRODUCER, conf, null, 0);
        if (kafka_producer == null) {
            @panic("Failed to create Kafka producer");
            //return null;
        }

        const topic_conf = librdkafka.rd_kafka_topic_conf_new();
        if (topic_conf == null) {
            @panic("Failed to create topic configuration");
            //return null;
        }

        const kafka_topic = librdkafka.rd_kafka_topic_new(kafka_producer, topic, topic_conf);
        if (kafka_topic == null) {
            @panic("Failed to create Kafka topic");
            //return null;
        }
        std.log.info("kafka producer initialized", .{});
        return .{ ._producer = kafka_producer, ._topic = kafka_topic };
    }

    pub fn deinit(self: Producer) void {
        librdkafka.rd_kafka_destroy(self._producer);
        std.log.info("kafka producer deinitialized", .{});
    }

    pub fn send(self: Producer, message: []const u8, key: []const u8) void {
        const message_ptr: ?*anyopaque = @constCast(message.ptr);
        const key_ptr: ?*anyopaque = @constCast(key.ptr);
        const err = librdkafka.rd_kafka_produce(
            self._topic,
            librdkafka.RD_KAFKA_PARTITION_UA,
            librdkafka.RD_KAFKA_MSG_F_COPY,
            message_ptr,
            message.len,
            key_ptr,
            key.len,
            null,
        );

        if (err != 0) {
            std.log.err("Failed to send message: {s}", .{librdkafka.rd_kafka_err2str(librdkafka.rd_kafka_last_error())});
        } else {
            std.log.info("Message sent successfully!", .{});
        }
    }

    pub fn wait(self: Producer) void {
        while (librdkafka.rd_kafka_outq_len(self._producer) > 0) {
            _ = librdkafka.rd_kafka_poll(self._producer, 100);
        }
    }
};

test "test get Producer Ok" {
    var ConfigBuilder = config.Builder.get();
    const producer_config = ConfigBuilder
        .withBootstrapServers("localhost:9092")
        .withLingerMs("5")
        .withBatchSize("10")
        .build();

    const kafka_producer = Producer.init(producer_config, "foobar-topic");
    assert(@TypeOf(kafka_producer) == Producer);
    kafka_producer.deinit();
}
