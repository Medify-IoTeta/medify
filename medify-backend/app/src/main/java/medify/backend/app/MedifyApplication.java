package medify.backend.app;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication(scanBasePackages = "medify.backend")
@EnableJpaRepositories(basePackages = "medify.backend")
@EntityScan(basePackages = "medify.backend")
@EnableScheduling
public class MedifyApplication {
    public static void main(String[] args) {
        SpringApplication.run(MedifyApplication.class, args);
    }
}