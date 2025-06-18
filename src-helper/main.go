package main

import (
	"log"

	"piControlHelper/handlers"
	"piControlHelper/utils"

	"github.com/gofiber/fiber/v2"
)

func main() {
	// Initialize TOTP authentication
	if err := handlers.InitializeAuth(); err != nil {
		log.Fatalf("Failed to initialize authentication: %v", err)
	}

	app := fiber.New()

	// Public endpoints (no authentication required)
	app.Get("/status", func(c *fiber.Ctx) error {
		distro := utils.IdentifyDistro()
		return c.JSON(fiber.Map{"status": "running", "distribution": distro})
	})

	// Authentication endpoints
	app.Post("/auth", handlers.AuthenticateHandler)
	app.Get("/auth/status", handlers.GetAuthStatus)

	// Protected API group (requires authentication)
	api := app.Group("/api", handlers.AuthMiddleware)

	// Package management endpoints
	api.Post("/install", handlers.InstallPackages)
	api.Post("/uninstall", handlers.UninstallPackages)
	api.Get("/search", handlers.SearchPackages)
	api.Get("/list_installed", handlers.ListInstalledPackages)

	// Service management endpoints
	api.Get("/services", handlers.ListServices)
	api.Get("/service/status", handlers.ServiceStatus)
	api.Post("/service/control", handlers.ControlService)

	// Authentication management endpoints
	api.Get("/auth/session", handlers.GetSessionStatus)
	api.Post("/auth/regenerate", handlers.RegenerateTOTP)
	api.Post("/auth/logout", handlers.LogoutHandler)

	log.Println("Starting PiControl Helper on distribution:", utils.IdentifyDistro())
	log.Fatal(app.Listen(":8220"))
}
