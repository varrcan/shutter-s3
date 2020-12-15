package main

import (
	"encoding/json"
	"github.com/rhnvrm/simples3"
	"io"
	"io/ioutil"
	"log"
	"mime"
	"net/url"
	"os"
	"os/user"
	"path/filepath"
)

type Settings struct {
	S3AccessKeyId     string
	S3SecretAccessKey string
	S3Bucket          string
	S3Url             string
}

func handleError(err error) {
	if err != nil {
		log.Fatal(err)
	}
}

func main() {
	argLen := len(os.Args)
	if argLen < 2 {
		return
	}

	filePath := os.Args[1]

	settings := loadSettings()

	file, fileErr := os.Open(filePath)
	fileInfo, _ := file.Stat()
	handleError(fileErr)
	defer file.Close()

	extension := filepath.Ext(fileInfo.Name())
	contentType := mime.TypeByExtension(extension)

	_ = simples3.S3{URIFormat: "https://%s.s3.yandexcloud.net/%s"}

	s3 := simples3.New("ru-central1", settings.S3AccessKeyId, settings.S3SecretAccessKey)
	s3.SetEndpoint("storage.yandexcloud.net")

	_, err := s3.FileUpload(simples3.UploadInput{
		Bucket:      settings.S3Bucket,
		ObjectKey:   fileInfo.Name(),
		ContentType: contentType,
		Body:        file,
	})

	handleError(err)

	url := s3.GeneratePresignedURL(simples3.PresignedInput{
		Bucket:    settings.S3Bucket,
		ObjectKey: fileInfo.Name(),
		Method:    "GET",
		Endpoint:  settings.S3Url,
	})

	url = stripQueryString(url)

	io.WriteString(os.Stdout, url)
}

func loadSettings() Settings {
	usr, userErr := user.Current()
	handleError(userErr)

	data, readErr := ioutil.ReadFile(usr.HomeDir + "/.shutter/shutter-config")
	handleError(readErr)

	var obj Settings

	pars := json.Unmarshal(data, &obj)
	handleError(pars)

	return obj
}

func stripQueryString(inputUrl string) string {
	u, err := url.Parse(inputUrl)
	handleError(err)

	u.RawQuery = ""
	return u.String()
}
