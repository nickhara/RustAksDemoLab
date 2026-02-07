namespace WorkerService;

using RabbitMQ.Client;
using RabbitMQ.Client.Events;
using System.Text;
using System.Text.Json;

public class Worker : BackgroundService
{
    private readonly ILogger<Worker> _logger;
    private readonly IConfiguration _configuration;
    private IConnection? _connection;
    private IChannel? _channel;
    private int _messagesProcessed = 0;

    public Worker(ILogger<Worker> logger, IConfiguration configuration)
    {
        _logger = logger;
        _configuration = configuration;
    }

    public override async Task StartAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Worker service starting...");
        
        var host = _configuration["RabbitMQ:Host"] ?? "localhost";
        var port = _configuration.GetValue<int>("RabbitMQ:Port", 5672);
        var username = _configuration["RabbitMQ:Username"] ?? "admin";
        var password = _configuration["RabbitMQ:Password"] ?? "admin123";
        var queue = _configuration["RabbitMQ:Queue"] ?? "task-queue";

        var factory = new ConnectionFactory
        {
            HostName = host,
            Port = port,
            UserName = username,
            Password = password
        };

        try
        {
            _connection = await factory.CreateConnectionAsync();
            _channel = await _connection.CreateChannelAsync();

            await _channel.QueueDeclareAsync(
                queue: queue,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null
            );

            await _channel.BasicQosAsync(prefetchSize: 0, prefetchCount: 1, global: false);

            _logger.LogInformation("Connected to RabbitMQ at {Host}:{Port}, listening on queue '{Queue}'", 
                host, port, queue);

            await base.StartAsync(cancellationToken);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to connect to RabbitMQ");
            throw;
        }
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (_channel == null)
        {
            _logger.LogError("Channel is not initialized");
            return;
        }

        var queue = _configuration["RabbitMQ:Queue"] ?? "task-queue";
        var processingDelay = _configuration.GetValue<int>("ProcessingDelayMs", 2000);

        var consumer = new AsyncEventingBasicConsumer(_channel);
        
        consumer.ReceivedAsync += async (model, ea) =>
        {
            var body = ea.Body.ToArray();
            var message = Encoding.UTF8.GetString(body);
            
            try
            {
                var taskMessage = JsonSerializer.Deserialize<TaskMessage>(message);
                
                if (taskMessage != null)
                {
                    _logger.LogInformation("Processing message {MessageId} of type '{TaskType}'", 
                        taskMessage.Id, taskMessage.TaskType);
                    
                    await Task.Delay(processingDelay, stoppingToken);
                    
                    _messagesProcessed++;
                    _logger.LogInformation("Successfully processed message {MessageId}. Total processed: {Count}", 
                        taskMessage.Id, _messagesProcessed);
                    
                    await _channel.BasicAckAsync(deliveryTag: ea.DeliveryTag, multiple: false);
                }
                else
                {
                    _logger.LogWarning("Received null task message, rejecting");
                    await _channel.BasicNackAsync(deliveryTag: ea.DeliveryTag, multiple: false, requeue: false);
                }
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "Failed to deserialize message, rejecting");
                await _channel.BasicNackAsync(deliveryTag: ea.DeliveryTag, multiple: false, requeue: false);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing message, requeuing");
                await _channel.BasicNackAsync(deliveryTag: ea.DeliveryTag, multiple: false, requeue: true);
            }
        };

        await _channel.BasicConsumeAsync(
            queue: queue,
            autoAck: false,
            consumer: consumer
        );

        _logger.LogInformation("Worker started consuming messages from queue '{Queue}'", queue);

        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(5000, stoppingToken);
            _logger.LogInformation("Worker is running. Messages processed: {Count}", _messagesProcessed);
        }
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("Worker service stopping. Total messages processed: {Count}", _messagesProcessed);
        
        if (_channel != null)
        {
            await _channel.CloseAsync();
            _channel.Dispose();
        }

        if (_connection != null)
        {
            await _connection.CloseAsync();
            _connection.Dispose();
        }

        await base.StopAsync(cancellationToken);
    }
}

public class TaskMessage
{
    public string Id { get; set; } = string.Empty;
    public string TaskType { get; set; } = string.Empty;
    public JsonElement Payload { get; set; }
    public string Timestamp { get; set; } = string.Empty;
}
