# Variables
$baseUrl = "http://localhost:8080"
$logFile = "alert_test_log.txt"
$tokenEndpoint = "$baseUrl/auth/token?sub=test-user&scope=USER"
$paymentsEndpoint = "$baseUrl/events/payments"
$alertsDbEndpoint = "$baseUrl/alerts-db"
$alertsKafkaEndpoint = "$baseUrl/alerts?timeoutMs=5000"

# Limpiar el archivo de log anterior
Clear-Content $logFile

Function Log-Output {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

Log-Output "--- INICIO DE LA PRUEBA DE ALERTAS ---"

# Pausa inicial para asegurar que la aplicación esté completamente iniciada
Log-Output "Esperando 10 segundos a que la aplicación se inicie por completo..."
Start-Sleep -Seconds 10

# 1. Obtener Token JWT
Log-Output "Paso 1: Obteniendo token JWT..."
try {
    $token = Invoke-RestMethod -Uri $tokenEndpoint -Method Get
    Log-Output "Token JWT obtenido exitosamente."
    Log-Output "Token: $token"
} catch {
    Log-Output "ERROR: No se pudo obtener el token JWT."
    Log-Output $_.Exception.Message
    exit
}

# 2. Enviar una transacción de pago que supere el umbral de alerta (e.g., > 10000)
Log-Output "`nPaso 2: Enviando transacción de pago sospechosa (monto: 15000)..."
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type" = "application/json"
}
$paymentBody = @{
    id = [System.Guid]::NewGuid().ToString()
    userId = [System.Guid]::NewGuid().ToString()
    amount = 15000
    timestamp = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
} | ConvertTo-Json

try {
    $paymentResponse = Invoke-WebRequest -Uri $paymentsEndpoint -Method Post -Headers $headers -Body $paymentBody
    Log-Output "Transacción enviada. Código de respuesta: $($paymentResponse.StatusCode)"
    Log-Output "Respuesta: $($paymentResponse.Content)"
} catch {
    Log-Output "ERROR: Falló el envío de la transacción."
    Log-Output $_.Exception.Message
    exit
}

# Pausa para dar tiempo a que se procese el evento
Log-Output "`nPausa de 5 segundos para el procesamiento asíncrono..."
Start-Sleep -Seconds 5

# 3. Verificar si la alerta se creó en la base de datos
Log-Output "`nPaso 3: Verificando si la alerta fue persistida en la base de datos..."
try {
    $alertsDbResponse = Invoke-WebRequest -Uri $alertsDbEndpoint -Method Get -Headers $headers
    Log-Output "Consulta a la base de datos de alertas exitosa. Código de respuesta: $($alertsDbResponse.StatusCode)"
    Log-Output "Alertas en la BD: $($alertsDbResponse.Content)"
} catch {
    Log-Output "ERROR: No se pudo consultar las alertas en la base de datos."
    Log-Output $_.Exception.Message
}

# 4. Consumir la alerta desde el topic de Kafka
Log-Output "`nPaso 4: Consumiendo la alerta desde el topic de Kafka 'alerts.suspect'..."
try {
    $alertsKafkaResponse = Invoke-WebRequest -Uri $alertsKafkaEndpoint -Method Get -Headers $headers
    Log-Output "Consumo del topic de Kafka exitoso. Código de respuesta: $($alertsKafkaResponse.StatusCode)"
    Log-Output "Alerta consumida de Kafka: $($alertsKafkaResponse.Content)"
} catch {
    Log-Output "ERROR: No se pudo consumir la alerta desde Kafka."
    Log-Output $_.Exception.Message
}

Log-Output "`n--- FIN DE LA PRUEBA DE ALERTAS ---"
Log-Output "Revisa el archivo '$logFile' para ver el detalle completo."