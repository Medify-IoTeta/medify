package medify.backend.app;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication(scanBasePackages = "medify.backend")
@EnableScheduling
public class MedifyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MedifyApplication.class, args);
    }
}