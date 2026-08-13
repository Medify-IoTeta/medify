# --- Build stage ---
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# Copy poms first so dependency resolution is cached across source-only changes
COPY pom.xml .
COPY domain/pom.xml domain/pom.xml
COPY data/pom.xml data/pom.xml
COPY api/pom.xml api/pom.xml
COPY app/pom.xml app/pom.xml
RUN mvn -q -B dependency:go-offline -pl app -am || true

COPY domain domain
COPY data data
COPY api api
COPY app app
RUN mvn -q -B -pl app -am clean package -DskipTests

# --- Runtime stage ---
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

RUN addgroup -S medify && adduser -S medify -G medify
COPY --from=build /build/app/target/*.jar app.jar
RUN chown medify:medify app.jar
USER medify

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget -q -O - http://localhost:8080/actuator/health | grep -q '"status":"UP"' || exit 1

ENTRYPOINT ["java", "-jar", "app.jar"]
