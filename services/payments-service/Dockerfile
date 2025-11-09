FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/payments-service-0.1.0.jar app.jar
EXPOSE 9101
ENTRYPOINT ["java","-jar","/app/app.jar"]