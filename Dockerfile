# Build stage
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /workspace
COPY pom.xml .
# Use offline mode if dependencies are already cached
RUN mvn -q -e -B -DskipTests dependency:resolve-sources dependency:resolve || \
    mvn -q -e -B -DskipTests dependency:go-offline -o || \
    mvn -q -e -B -DskipTests dependency:go-offline
COPY src ./src
RUN mvn -q -e -B -DskipTests clean package -o || \
    mvn -q -e -B -DskipTests clean package

# Run stage
FROM eclipse-temurin:17-jre-jammy
ENV JAVA_OPTS="-Xms256m -Xmx512m"
WORKDIR /app

# Instalar curl para health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY --from=build /workspace/target/eda-backend-0.1.0.jar app.jar
EXPOSE 8080
ENTRYPOINT [ "sh", "-c", "java $JAVA_OPTS -jar app.jar" ]
