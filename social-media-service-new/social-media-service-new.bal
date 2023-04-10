import ballerina/regex;
import ballerina/http;
import ballerina/time;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/sql;

type User record {
    int id;
    string name;
    time:Date birthDate;
    @sql:Column {name: "mobile_number"}
    string mobileNumber;
};

type PostForbidden record {
    *http:Forbidden;
    ErrorDetails body;
};

type Post record {
    int id;
    string description;
    string tags;
    string category;
    time:Date created_date;
};

type PostWithMeta record {
    int id;
    string description;
    record {
        string[] tags;
        string category;
        time:Date created_date;
    } meta;
};

type NewPost record {
    string description;
    string tags;
    string category;
};

type ErrorDetails record {

};

type UserNotFound record {
    *http:NotFound;
    ErrorDetails body;
};

final mysql:Client socialMediaDb = check new ("localhost", "root", "admin", "social_media_database", 3306);

function transform(User user) returns Post => {
    created_date: user.birthDate

};

service /social\-media on new http:Listener(9090) {

    resource function get users() returns User[]|error {
        stream<User, sql:Error?> userStream = socialMediaDb->query(`SELECT * from users`);
        User[] users = check from User user1 in userStream
            select user1;
        return users;
    }

    resource function get users/[int id]/posts() returns PostWithMeta[]|UserNotFound|error {
        User|error result = socialMediaDb->queryRow(`SELECT * FROM users WHERE id = ${id}`);
        if result is sql:NoRowsError {
            ErrorDetails errorDetails = buildErrorPayload(string `id: ${id}`, string `users/${id}/posts`);
            UserNotFound userNotFound = {
                body: errorDetails
            };
            return userNotFound;
        }
        stream<Post, sql:Error?> postStream = socialMediaDb->query(`SELECT id, description, category, created_date, tags FROM posts WHERE user_id = ${id}`);
        Post[]|error posts = from Post post in postStream
            select post;
        return postToPostWithMeta(check posts);
    }
    resource function post users/[int id]/posts(@http:Payload NewPost newPost) returns http:Created|UserNotFound|PostForbidden|error {
        User|error user = socialMediaDb->queryRow(`SELECT * FROM users WHERE id = ${id}`);
        if user is sql:NoRowsError {
            ErrorDetails errorDetails = buildErrorPayload(string `id: ${id}`, string `users/${id}/posts`);
            UserNotFound userNotFound = {
                body: errorDetails
            };
            return userNotFound;
        }
        if user is error {
            return user;
        }
        _ = check socialMediaDb->execute(`
            INSERT INTO posts(description, category, created_date, tags, user_id)
            VALUES (${newPost.description}, ${newPost.category}, CURDATE(), ${newPost.tags}, ${id});`);
        return http:CREATED;
    }
}

function postToPostWithMeta(Post[] post) returns PostWithMeta[] => from var postItem in post
    select {
        id: postItem.id,
        description: postItem.description,
        meta: {
            tags: regex:split(postItem.tags, ","),
            category: postItem.category,
            created_date: {
                utcOffset: postItem.created_date.utcOffset,
                year: postItem.created_date.year,
                month: postItem.created_date.month,
                day: postItem.created_date.day,
                hour: postItem.created_date.hour,
                minute: postItem.created_date.minute,
                second: postItem.created_date.second
            }
        }
    };

function buildErrorPayload(string msg, string path) returns ErrorDetails => {

};

