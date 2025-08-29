FROM eclipse-temurin:17-jre
WORKDIR /app

ARG JAR_FILE=target/*.jar
COPY ${JAR_FILE} app.jar
EXPOSE 8080

ENV JAVA_OPTS=""
RUN mkdir -p /otel
COPY otel/opentelemetry-javaagent.jar /otel/opentelemetry-javaagent.jar
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/app.jar"]
