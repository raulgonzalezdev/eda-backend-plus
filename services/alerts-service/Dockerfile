FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/alerts-service-0.1.0.jar app.jar
EXPOSE 9103
ENTRYPOINT ["java","-jar","/app/app.jar"]